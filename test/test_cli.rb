require 'helper'
require 'stompkiq/cli'
require 'tempfile'

cli = Stompkiq::CLI.instance
def cli.die(code)
  @code = code
end

def cli.valid?
  !@code
end

class TestCli < MiniTest::Unit::TestCase
  describe 'with cli' do

    before do
      @cli = Stompkiq::CLI.instance
    end

    it 'blows up with an invalid require' do
      assert_raises ArgumentError do
        @cli.parse(['stompkiq', '-r', 'foobar'])
      end
    end

    it 'requires the specified Ruby code' do
      @cli.parse(['stompkiq', '-r', './test/fake_env.rb'])
      assert($LOADED_FEATURES.any? { |x| x =~ /fake_env/ })
      assert @cli.valid?
    end

    it 'changes concurrency' do
      @cli.parse(['stompkiq', '-c', '60', '-r', './test/fake_env.rb'])
      assert_equal 60, Stompkiq.options[:concurrency]
    end

    it 'changes queues' do
      @cli.parse(['stompkiq', '-q', 'foo', '-r', './test/fake_env.rb'])
      assert_equal ['foo'], Stompkiq.options[:queues]
    end

    it 'changes timeout' do
      @cli.parse(['stompkiq', '-t', '30', '-r', './test/fake_env.rb'])
      assert_equal 30, Stompkiq.options[:timeout]
    end

    it 'handles multiple queues with weights' do
      @cli.parse(['stompkiq', '-q', 'foo,3', '-q', 'bar', '-r', './test/fake_env.rb'])
      assert_equal %w(bar foo foo foo), Stompkiq.options[:queues].sort
    end

    it 'sets verbose' do
      old = Stompkiq.logger.level
      @cli.parse(['stompkiq', '-v', '-r', './test/fake_env.rb'])
      assert_equal Logger::DEBUG, Stompkiq.logger.level
      # If we leave the logger at DEBUG it'll add a lot of noise to the test output
      Stompkiq.logger.level = old
    end

    describe 'with pidfile' do
      before do
        @tmp_file = Tempfile.new('stompkiq-test')
        @tmp_path = @tmp_file.path
        @tmp_file.close!

        @cli.parse(['stompkiq', '-P', @tmp_path, '-r', './test/fake_env.rb'])
      end

      after do
        File.unlink @tmp_path if File.exist? @tmp_path
      end

      it 'sets pidfile path' do
        assert_equal @tmp_path, Stompkiq.options[:pidfile]
      end

      it 'writes pidfile' do
        assert_equal File.read(@tmp_path).strip.to_i, Process.pid
      end
    end

    describe 'with config file' do
      before do
        @cli.parse(['stompkiq', '-C', './test/config.yml'])
      end

      it 'takes a path' do
        assert_equal './test/config.yml', Stompkiq.options[:config_file]
      end

      it 'sets verbose' do
        refute Stompkiq.options[:verbose]
      end

      it 'sets require file' do
        assert_equal './test/fake_env.rb', Stompkiq.options[:require]
      end

      it 'sets environment' do
        assert_equal 'xzibit', Stompkiq.options[:environment]
      end

      it 'sets concurrency' do
        assert_equal 50, Stompkiq.options[:concurrency]
      end

      it 'sets pid file' do
        assert_equal '/tmp/stompkiq-config-test.pid', Stompkiq.options[:pidfile]
      end

      it 'sets queues' do
        assert_equal 2, Stompkiq.options[:queues].count { |q| q == 'often' }
        assert_equal 1, Stompkiq.options[:queues].count { |q| q == 'seldom' }
      end
    end

    describe 'with config file and flags' do
      before do
        # We need an actual file here.
        @tmp_lib_path = '/tmp/require-me.rb'
        File.open(@tmp_lib_path, 'w') do |f|
          f.puts "# do work"
        end

        @tmp_file = Tempfile.new('stompkiqr')
        @tmp_path = @tmp_file.path
        @tmp_file.close!

        @cli.parse(['stompkiq',
                    '-C', './test/config.yml',
                    '-e', 'snoop',
                    '-c', '100',
                    '-r', @tmp_lib_path,
                    '-P', @tmp_path,
                    '-q', 'often,7',
                    '-q', 'seldom,3',
                    '-E', '1'])
      end

      after do
        File.unlink @tmp_lib_path if File.exist? @tmp_lib_path
        File.unlink @tmp_path if File.exist? @tmp_path
      end

      it 'uses concurrency flag' do
        assert_equal 100, Stompkiq.options[:concurrency]
      end

      it 'uses require file flag' do
        assert_equal @tmp_lib_path, Stompkiq.options[:require]
      end

      it 'uses environment flag' do
        assert_equal 'snoop', Stompkiq.options[:environment]
      end

      it 'uses eventorigination flag' do
        assert Stompkiq.options[:event_origination]
      end

      it 'uses pidfile flag' do
        assert_equal @tmp_path, Stompkiq.options[:pidfile]
      end

      it 'sets queues' do
        assert_equal 7, Stompkiq.options[:queues].count { |q| q == 'often' }
        assert_equal 3, Stompkiq.options[:queues].count { |q| q == 'seldom' }
      end
    end
  end

end
