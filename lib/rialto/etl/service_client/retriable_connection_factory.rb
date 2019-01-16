# frozen_string_literal: true

require 'active_support/core_ext/class/attribute'
require 'faraday'

module Rialto
  module Etl
    module ServiceClient
      # Builds Faraday connections with retry and long timeouts
      class RetriableConnectionFactory
        DEFAULT_MAX_RETRIES = 6
        DEFAULT_MAX_INTERVAL = Float::MAX
        class_attribute :logger, :max_retries, :max_interval

        # rubocop:disable Metrics/ParameterLists
        def self.build(uri:, headers: nil, oath_token: nil, logger: default_logger, max_retries: nil, max_interval: nil)
          self.logger = logger
          self.max_retries = max_retries || DEFAULT_MAX_RETRIES
          self.max_interval = max_interval || DEFAULT_MAX_INTERVAL

          return retriable_connection(uri: uri, headers: headers) if oath_token.nil?
          retriable_oath_connection(uri: uri, oath_token: oath_token)
        end
        # rubocop:enable Metrics/ParameterLists

        # rubocop:disable Metrics/MethodLength
        def self.retriable_connection(uri:, headers:)
          Faraday.new(uri, headers: headers) do |connection|
            connection.request :retry,
                               max: max_retries,
                               max_interval: max_interval,
                               interval: 5.0,
                               interval_randomness: 0.01,
                               backoff_factor: 2.0,
                               methods: retriable_methods,
                               exceptions: retriable_exceptions,
                               retry_block: retry_block,
                               retry_statuses: retry_statuses

            connection.ssl.update(verify: true, verify_mode: OpenSSL::SSL::VERIFY_PEER)
            # Use :net_http instead of :net_http_persistent to avoid getaddrbyinfo errors with DNS resolution
            connection.adapter :net_http
            connection.options.timeout = 500
            connection.options.open_timeout = 10
          end
        end
        private_class_method :retriable_connection

        def self.retriable_oath_connection(uri:, oath_token:)
          Faraday.new(uri) do |connection|
            connection.request :oauth2,
                               oath_token,
                               token_type: :bearer,
                               max: max_retries,
                               max_interval: max_interval,
                               interval: 5.0,
                               interval_randomness: 0.01,
                               backoff_factor: 2.0,
                               methods: retriable_methods,
                               exceptions: retriable_exceptions,
                               retry_block: retry_block,
                               retry_statuses: retry_statuses
            connection.adapter Faraday.default_adapter
          end
        end
        private_class_method :retriable_oath_connection
        # rubocop:enable Metrics/MethodLength

        def self.retriable_methods
          Faraday::Request::Retry::IDEMPOTENT_METHODS + [:post]
        end
        private_class_method :retriable_methods

        def self.retriable_exceptions
          Faraday::Request::Retry::DEFAULT_EXCEPTIONS + [Faraday::ConnectionFailed, ErrorResponse]
        end
        private_class_method :retriable_exceptions

        def self.retry_block
          lambda { |env, _opts, retries, exception|
            logger.warn "retrying connection (#{retries} remaining) to #{env.url}: (#{exception.class}) " \
              "#{exception.message} #{env.status}"
          }
        end
        private_class_method :retry_block

        def self.default_logger
          Yell.new(STDERR)
        end
        private_class_method :default_logger

        def self.retry_statuses
          [429, 500, 502, 503, 504, 599]
        end
        private_class_method :retry_statuses
      end
    end
  end
end
