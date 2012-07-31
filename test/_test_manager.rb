require 'helper'
require 'stompkiq'
require 'stompkiq/manager'

# for TimedQueue
require 'connection_pool'

class TestManager < MiniTest::Unit::TestCase
  describe 'with redis' do
    before do
      Stompkiq.redis = REDIS
      Stompkiq.redis {|c| c.flushdb }
      $processed = 0
      $mutex = Mutex.new
    end

    class IntegrationWorker
      include Stompkiq::Worker
      stompkiq_options :queue => 'foo'

      def perform(a, b)
        $mutex.synchronize do
          $processed += 1
        end
        a + b
      end
    end

    it 'processes messages' do
      IntegrationWorker.perform_async(1, 2)
      IntegrationWorker.perform_async(1, 3)

      q = TimedQueue.new
      mgr = Stompkiq::Manager.new(:queues => [:foo], :concurrency => 2)
      mgr.when_done do |_|
        q << 'done' if $processed == 2
      end
      mgr.start!
      result = q.timed_pop(1.0)
      assert_equal 'done', result
      mgr.stop
      mgr.terminate

      # Gross bloody hack because I can't get the actor threads
      # to shut down cleanly in the test.  Need @bascule's help here.
      (Thread.list - [Thread.current]).each do |t|
        t.raise Interrupt
      end
    end
  end
end
