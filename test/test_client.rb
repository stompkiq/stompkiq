require 'helper'
require 'stompkiq/client'
require 'stompkiq/worker'

class TestClient < MiniTest::Unit::TestCase
  describe 'with mock redis' do
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

    it 'pushes messages to redis' do
      @stomp.expect :publish, nil, ['/queue/foo', String]
#      @redis.expect :rpush, 1, ['/queue/foo', String]
      pushed = Stompkiq::Client.push('queue' => 'foo', 'class' => MyWorker, 'args' => [1, 2])
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
      @redis.expect :rpush, 1, ['queue:default', String]
      pushed = MyWorker.perform_async(1, 2)
      assert pushed
      @redis.verify
    end

    it 'handles perform_async on failure' do
      @redis.expect :rpush, nil, ['queue:default', String]
      pushed = MyWorker.perform_async(1, 2)
      refute pushed
      @redis.verify
    end

    it 'enqueues messages to redis' do
      @redis.expect :rpush, 1, ['queue:default', String]
      pushed = Stompkiq::Client.enqueue(MyWorker, 1, 2)
      assert pushed
      @redis.verify
    end

    class QueuedWorker
      include Stompkiq::Worker
      stompkiq_options :queue => :flimflam, :timeout => 1
    end

    it 'enqueues to the named queue' do
      @redis.expect :rpush, 1, ['queue:flimflam', String]
      pushed = QueuedWorker.perform_async(1, 2)
      assert pushed
      @redis.verify
    end

    it 'retrieves queues' do
      @redis.expect :smembers, ['bob'], ['queues']
      assert_equal ['bob'], Stompkiq::Client.registered_queues
    end

    it 'retrieves workers' do
      @redis.expect :smembers, ['bob'], ['workers']
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
      assert_equal 'base', AWorker.get_stompkiq_options['retry']
      assert_equal 'b', BWorker.get_stompkiq_options['retry']
    end
  end

end
