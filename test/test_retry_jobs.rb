require 'helper'
require 'stompkiq/scheduled'
require 'stompkiq/middleware/server/retry_jobs'

class TestRetry < MiniTest::Unit::TestCase
  describe 'middleware' do
    before do
      @redis = MiniTest::Mock.new
      # Ugh, this is terrible.
      Stompkiq.instance_variable_set(:@redis, @redis)

      def @redis.with; yield self; end

      @stomp = MiniTest::Mock.new
      # Ugh, this is terrible.
      Stompkiq.instance_variable_set(:@stomp, @stomp)

      def @stomp.with; yield self; end
    end

    it 'allows disabling retry' do
      msg = { :class => 'Bob', :args => [1,2,'foo'], :retry => false }
      msg2 = msg.dup
      handler = Stompkiq::Middleware::Server::RetryJobs.new
      assert_raises RuntimeError do
        handler.call('', msg2, 'default') do
          raise "kerblammo!"
        end
      end
      assert_equal msg, msg2
    end

    it 'saves backtraces' do
      @redis.expect :zadd, 1, [:retry, String, String]
      msg = { :class => 'Bob', :args => [1,2,'foo'], :retry => true, :backtrace => true }
      handler = Stompkiq::Middleware::Server::RetryJobs.new
      c = nil
      assert_raises RuntimeError do
        handler.call('', msg, 'default') do
          c = caller(0); raise "kerblammo!"
        end
      end
      assert msg[:error_backtrace]
      assert_equal c, msg[:error_backtrace]
    end

    it 'saves partial backtraces' do
      @redis.expect :zadd, 1, [:retry, String, String]
      msg = { :class => 'Bob', :args => [1,2,'foo'], :retry => true, :backtrace => 3 }
      handler = Stompkiq::Middleware::Server::RetryJobs.new
      c = nil
      assert_raises RuntimeError do
        handler.call('', msg, 'default') do
          c = caller(0)[0..3]; raise "kerblammo!"
        end
      end
      assert msg[:error_backtrace]
      assert_equal c, msg[:error_backtrace]
    end

    it 'handles a new failed message' do
      @redis.expect :zadd, 1, [:retry, String, String]
      msg = { :class => 'Bob', :args => [1,2,'foo'], :retry => true }
      handler = Stompkiq::Middleware::Server::RetryJobs.new
      assert_raises RuntimeError do
        handler.call('', msg, 'default') do
          raise "kerblammo!"
        end
      end
      assert_equal 'default', msg[:queue]
      assert_equal 'kerblammo!', msg[:error_message]
      assert_equal 'RuntimeError', msg[:error_class]
      assert_equal 0, msg[:retry_count]
      refute msg[:error_backtrace]
      assert msg[:failed_at]
      @redis.verify
    end

    it 'handles a recurring failed message' do
      @redis.expect :zadd, 1, [:retry, String, String]
      now = Time.now.utc
      msg = {:class=>"Bob", :args=>[1, 2, "foo"], :retry => true, :queue=>"default", :error_message=>"kerblammo!", :error_class=>"RuntimeError", :failed_at=>now, :retry_count=>10}
      handler = Stompkiq::Middleware::Server::RetryJobs.new
      assert_raises RuntimeError do
        handler.call('', msg, 'default') do
          raise "kerblammo!"
        end
      end
      assert_equal 'default', msg[:queue]
      assert_equal 'kerblammo!', msg[:error_message]
      assert_equal 'RuntimeError', msg[:error_class]
      assert_equal 11, msg[:retry_count]
      assert msg[:failed_at]
      @redis.verify
    end

    it 'throws away old messages after too many retries' do
      now = Time.now.utc
      msg = {:class=>"Bob", :args=>[1, 2, "foo"], :queue=>"default", :error_message=>"kerblammo!", :error_class=>"RuntimeError", :failed_at=>now, :retry_count=>25}
      handler = Stompkiq::Middleware::Server::RetryJobs.new
      assert_raises RuntimeError do
        handler.call('', msg, 'default') do
          raise "kerblammo!"
        end
      end
      @redis.verify
    end
   end

  describe 'poller' do
    before do
      @redis = MiniTest::Mock.new
      Stompkiq.instance_variable_set(:@redis, @redis)

      def @redis.with; yield self; end
    end

    it 'should poll like a bad mother...SHUT YO MOUTH' do
      fake_msg = Stompkiq.dump_json({ :class => 'Bob', :args => [1,2], :queue => 'someq' })
      @redis.expect :multi, [[fake_msg], 1], []
      @redis.expect :multi, [[], nil], []
      @redis.expect :multi, [[], nil], []
      @redis.expect :multi, [[], nil], []

      inst = Stompkiq::Scheduled::Poller.new
      inst.poll

      @redis.verify
    end
  end

end
