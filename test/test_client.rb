GGrequire 'helper'
require 'stompkiq/client'
require 'stompkiq/worker'
require 'stomp'

class TestClient < MiniTest::Unit::TestCase
  describe 'with mock redis and mock stomp' do
    before do
      @redis = MiniTest::Mock.new
      def @redis.multi; [yield] * 2 if block_given?; end
      def @redis.set(*); true; end
      def @redis.sadd(*); true; end
      def @redis.srem(*); true; end
      def @redis.get(*); nil; end
      def @redis.del(*); nil; end
      def @redis.incrby(*); nil; end
      def @redis.setex(*); true; end
      def @redis.expire(*); true; end
      def @redis.watch(*); true; end
      def @redis.with_connection; yield self; end
      def @redis.with; yield self; end
      def @redis.exec; true; end
      Stompkiq.instance_variable_set(:@redis, @redis)

      @stomp = MiniTest::Mock.new
      def @stomp.with; yield self; end
      Stompkiq.instance_variable_set(:@stomp, @stomp)
    end

    it 'raises ArgumentError with invalid params' do
      assert_raises ArgumentError do
        Stompkiq::Client.push('foo', 1)
      end

      assert_raises ArgumentError do
        Stompkiq::Client.push('foo', :class => 'Foo', :noargs => [1, 2])
      end
    end

    it 'raises NotImplementedError with at param' do
      assert_raises NotImplementedError do
        Stompkiq::Client.push(:queue => 'foo', 'class' => MyWorker, 'args' => [1, 2], 'at' => 0.01)
      end
    end

    it 'pushes messages to stomp' do
      @stomp.expect :publish, true, ['/queue/foo', String]
      pushed = Stompkiq::Client.push(:queue => 'foo', 'class' => MyWorker, 'args' => [1, 2])
      assert pushed
      @stomp.verify
    end

    class MyWorker
      include Stompkiq::Worker
    end

    it 'has default options' do
      assert_equal Stompkiq::Worker::ClassMethods::DEFAULT_OPTIONS, MyWorker.get_stompkiq_options
    end

    it 'handles perform_async' do
      @stomp.expect :publish, nil, ['/queue/default', String] # I am expecting @stomp.publish('/queue/default', any_string) and I will return nil when it gets called
      pushed = MyWorker.perform_async(1, 2)
      assert pushed
      @stomp.verify
    end

    it 'handles perform_async on failure' do
      def @stomp.publish(*args); raise Stomp::Error::MaxReconnectAttempts; end
      pushed = MyWorker.perform_async(1, 2)
      refute pushed
    end

    it 'enqueues messages to stomp' do
      @stomp.expect :publish, true, ['/queue/default', String]
      pushed = Stompkiq::Client.enqueue(MyWorker, 1, 2)
      assert pushed
      @stomp.verify
    end

    class QueuedWorker
      include Stompkiq::Worker
      stompkiq_options :queue => :flimflam, :timeout => 1
    end

    it 'enqueues to the named queue' do
      @stomp.expect :publish, true, ['/queue/flimflam', String]
      pushed = QueuedWorker.perform_async(1, 2)
      assert pushed
      @stomp.verify
    end

    class TopicedWorker
      include Stompkiq::Worker
      stompkiq_options :queue => :flimflam, :queuetype => :topic, :timeout => 1
    end
    
    it 'enqueues to the named queue' do
      @stomp.expect :publish, true, ['/topic/flimflam', String]
      pushed = TopicedWorker.perform_async(1, 2)
      assert pushed
      @stomp.verify
    end

    it 'retrieves queues' do
      # We'll still use Redis to store our registered queues and workers
      @redis.expect :smembers, ['bob'], [:queues]
      assert_equal ['bob'], Stompkiq::Client.registered_queues
    end

    it 'retrieves workers' do
      # We'll still use Redis to store our registered queues and workers
      @redis.expect :smembers, ['bob'], [:workers]
      assert_equal ['bob'], Stompkiq::Client.registered_workers
    end
  end

  class BaseWorker
    include Stompkiq::Worker
    stompkiq_options 'retry' => 'base'
  end
  class AWorker < BaseWorker
  end
  class BWorker < BaseWorker
    stompkiq_options 'retry' => 'b'
  end

  describe 'inheritance' do
    it 'should inherit stompkiq options' do
      assert_equal 'base', AWorker.get_stompkiq_options[:retry]
      assert_equal 'b', BWorker.get_stompkiq_options[:retry]
    end
  end

end
