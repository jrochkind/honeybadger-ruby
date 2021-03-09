# Auto required by spec_helper.rb
# https://relishapp.com/rspec/rspec-core/docs/example-groups/shared-examples
RSpec.shared_examples 'cli installer' do |rails|
  let(:config) { Honeybadger::Config.new(api_key: 'asdf', 'config.path': config_file) }

  before { set_environment_variable('HONEYBADGER_BACKEND', 'debug') }

  it 'outputs successful result' do
    output = capture(:stdout) { Honeybadger::CLI.start(%w[install asdf]) }
    expect(output).to match(/Writing configuration/i)
    expect(output).to match(/Happy 'badgering/i)
    expect(output).not_to match(/heroku/i)
    expect(output).not_to match(/Starting Honeybadger/i)
    if rails
      expect(output).to match(/Detected Rails/i)
    else
      expect(output).not_to match(/Detected Rails/i)
    end
  end

  it 'creates the configuration file' do
    FileUtils.rm config_file if File.exist?(config_file)

    expect do
      run_command('honeybadger install asdf')
    end.to change { config_file.exist? }.from(false).to(true)
  end

  it 'sends a test notification' do
    set_environment_variable('HONEYBADGER_LOGGING_LEVEL', '1')
    cmd = run_command('honeybadger install asdf')
    expect(cmd).to be_successfully_executed
    assert_notification(cmd.output, 'error' => { 'class' => 'HoneybadgerTestingException' })
  end

  context 'with the --no-test option' do
    it 'skips the test notification' do
      set_environment_variable('HONEYBADGER_LOGGING_LEVEL', '1')
      cmd = run_command('honeybadger install asdf --no-test')
      expect(cmd).to be_successfully_executed
      assert_no_notification(cmd.output)
    end
  end

  context 'when the configuration file already exists' do
    before { File.write(config_file, <<~YML) }
      ---
      api_key: 'asdf'
    YML

    it 'does not overwrite existing configuration' do
      cmd = run_command('honeybadger install asdf')
      expect(cmd).to be_successfully_executed
      expect do
        run_command('honeybadger install asdf')
      end.not_to change { config_file.mtime }
    end

    it 'outputs successful result' do
      cmd = run_command('honeybadger install asdf')
      expect(cmd).to be_successfully_executed
      expect(cmd.output).to match(/Happy 'badgering/i)
    end
  end

  context 'when capistrano is detected' do
    let(:capfile) { Pathname(current_dir).join('Capfile') }

    before { File.write(capfile, <<~YML) }
      if respond_to?(:namespace) # cap2 differentiator
        load 'deploy'
      else
        require 'capistrano/setup'
        require 'capistrano/deploy'
      end
    YML

    it 'installs capistrano command' do
      cmd = run_command('honeybadger install asdf')
      expect(cmd).to be_successfully_executed

      cmd = run_command('bundle exec cap -T')
      expect(cmd).to be_successfully_executed
      expect(cmd.output).to match(/honeybadger:deploy/i)
    end
  end
end
