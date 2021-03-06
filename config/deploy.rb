# frozen_string_literal: true

set :application, 'rialto-etl'
set :repo_url, 'https://github.com/sul-dlss/rialto-etl.git'

# Default branch is :main
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, '/opt/app/rialto/rialto'

# Set the honeybadger env to match the capistrano stage
set :honeybadger_env, fetch(:stage)

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
append :linked_files, 'config/honeybadger.yml'

# Default value for linked_dirs is []
append :linked_dirs, 'data', 'config/settings'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

# NOTE: Commented out to prevent crontab updates. Default whenever roles are `[:db]` which we do not use for rialto-etl.
# set :whenever_roles, [:app]

# update shared_configs
before 'bundler:install', 'shared_configs:update'
