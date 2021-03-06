# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe Rialto::Etl::CLI::Publications do
  subject(:loader) { described_class.new([], args, conf) }

  let(:args) do
    ['--force', '--input-directory', 'spec/fixtures/wos', '--output-directory', dir]
  end
  let(:command) { described_class.all_commands['load'] }
  let(:conf) do
    {
      current_command: command,
      command_options: command.options
    }
  end
  let(:dir) { Dir.mktmpdir }
  let(:record) do
    File.read('spec/fixtures/wos/WOS:000424386600014.json')
  end

  before do
    allow(Rialto::Etl::Loaders::Sparql).to receive(:new).and_return(double(load: true))
    allow(Rialto::Etl::Transformer).to receive(:new).and_return(double('t', transform: nil))
    allow(Rialto::Etl::Extractors::WebOfScience).to receive(:new).and_return([record.to_s])
    allow(File).to receive(:exist?).and_return(true)
    allow(File).to receive(:empty?).and_return(false)
  end

  describe '#load' do
    context 'when extracting, transforming, and loading' do
      it 'calls extract, transform, and load' do
        loader.invoke_command(command)
        expect(Rialto::Etl::Extractors::WebOfScience).to have_received(:new).once
        expect(Rialto::Etl::Transformer).to have_received(:new).once
        expect(Rialto::Etl::Loaders::Sparql).to have_received(:new)
          .with(input: "#{dir}/WOS:000424386600014.sparql")
      end
    end

    context 'with --skip-extract flag' do
      let(:args) do
        ['--force', '--input-directory', 'spec/fixtures/wos', '--output-directory', dir, '--skip-extract']
      end

      it 'skips the extract and runs the transform on every WOS:*.json file found' do
        loader.invoke_command(command)
        expect(Rialto::Etl::Extractors::WebOfScience).not_to have_received(:new)
        expect(Rialto::Etl::Transformer).to have_received(:new).twice
        expect(Rialto::Etl::Loaders::Sparql).to have_received(:new)
          .with(input: "#{dir}/WOS:000424386600014.sparql")
      end
    end

    context 'with --since flag' do
      let(:args) do
        ['--force', '--input-directory', 'spec/fixtures/wos', '--output-directory', dir, '--since', '2W']
      end

      it 'invokes the extractor with the `since` option supplied' do
        loader.invoke_command(command)
        expect(Rialto::Etl::Extractors::WebOfScience).to have_received(:new).once.with(since: '2W')
      end
    end

    context 'with --skip-load flag' do
      let(:args) do
        ['--force', '--input-directory', 'spec/fixtures/wos', '--output-directory', dir, '--skip-load']
      end

      it 'skips the load' do
        loader.invoke_command(command)
        expect(Rialto::Etl::Extractors::WebOfScience).to have_received(:new)
        expect(Rialto::Etl::Transformer).to have_received(:new).once
        expect(Rialto::Etl::Loaders::Sparql).not_to have_received(:new)
      end
    end

    context 'when source file already exists' do
      context 'without force argument' do
        let(:args) do
          ['--input-directory', 'spec/fixtures/wos', '--output-directory', dir]
        end

        before do
          # Want source file to exist and sparql file not to exist until in the
          # loader. This mimics the source_file existing, the transformation
          # succeeding, and the loader executing.
          allow(File).to receive(:exist?).and_return(true, false, true)
        end

        it 'runs extract and prints a warning' do
          loader.invoke_command(command)
          expect(Rialto::Etl::Extractors::WebOfScience).to have_received(:new).once
          expect(Rialto::Etl::Transformer).to have_received(:new).once
          expect(Rialto::Etl::Loaders::Sparql).to have_received(:new)
            .with(input: "#{dir}/WOS:000424386600014.sparql")
        end
      end
    end

    context 'when sparql file already exists' do
      context 'without force argument' do
        let(:args) do
          ['--input-directory', 'spec/fixtures/wos', '--output-directory', dir]
        end

        before do
          # Want source file to exist and sparql file to exist. This mimics the
          # source_file not existing, the transformation warning, and the loader
          # executing.
          allow(File).to receive(:exist?).and_return(false, true)
        end

        it 'runs `#transform` but does not invoke transformer' do
          loader.invoke_command(command)
          expect(Rialto::Etl::Extractors::WebOfScience).to have_received(:new).once
          expect(Rialto::Etl::Transformer).not_to have_received(:new)
          expect(Rialto::Etl::Loaders::Sparql).to have_received(:new)
            .with(input: "#{dir}/WOS:000424386600014.sparql")
        end
      end
    end

    context 'when exception raised during transform' do
      before do
        allow(Rialto::Etl::Transformer).to receive(:new).and_raise(StandardError)
        # Want source file to exist and sparql file not to exist. This mimics
        # the transformation removing the sparql file.
        allow(File).to receive(:exist?).and_return(true, false, false)
        allow(Rialto::Etl::CLI::ErrorReporter).to receive(:log_exception)
      end

      it 'raises an error' do
        expect { loader.invoke_command(command) }.to raise_error(StandardError)
        expect(Rialto::Etl::Extractors::WebOfScience).to have_received(:new).once
        expect(Rialto::Etl::Transformer).to have_received(:new).once
        expect(Rialto::Etl::Loaders::Sparql).not_to have_received(:new)
          .with(input: "#{dir}/WOS:000424386600014.sparql")
        expect(Rialto::Etl::CLI::ErrorReporter).to have_received(:log_exception)
      end
    end

    context 'when exception raised during load' do
      before do
        allow(Rialto::Etl::Loaders::Sparql).to receive(:new).and_raise(StandardError)
        allow(Rialto::Etl::CLI::ErrorReporter).to receive(:log_exception)
      end

      it 'raises an error' do
        expect { loader.invoke_command(command) }.to raise_error(StandardError)
        expect(Rialto::Etl::Extractors::WebOfScience).to have_received(:new).once
        expect(Rialto::Etl::Transformer).to have_received(:new).once
        expect(Rialto::Etl::Loaders::Sparql).to have_received(:new)
          .with(input: "#{dir}/WOS:000424386600014.sparql")
        expect(Rialto::Etl::CLI::ErrorReporter).to have_received(:log_exception)
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
