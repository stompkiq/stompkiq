require 'helper'
require 'stompkiq'
require 'stompkiq/processor'

class TestStats < MiniTest::Unit::TestCase
  describe 'with redis' do
    before do
      @redis = Stompkiq.redis = REDIS
      Stompkiq.redis {|c| c.flushdb }
    end

    class DumbWorker
      include Stompkiq::Worker

      def perform(arg)
        raise 'bang' if arg == nil
      end
    end

    it 'updates global stats in the success case' do
      msg = Stompkiq.dump_json({ :class => DumbWorker.to_s, :args => [""] })
      boss = MiniTest::Mock.new
 
      @redis.with do |conn|

        set = conn.smembers('workers')
        assert_equal 0, set.size

        puts 'about to make processor'
        processor = Stompkiq::Processor.new(boss)
        puts 'made processor'
        boss.expect(:processor_done!, nil, [processor])
        boss.expect(:processor_done!, nil, [processor])
        boss.expect(:processor_done!, nil, [processor])

        assert_equal 0, conn.get('stat:failed').to_i
        assert_equal 0, conn.get('stat:processed').to_i

        processor.process(msg, 'xyzzy')
        processor.process(msg, 'xyzzy')
        processor.process(msg, 'xyzzy')

        assert_equal 0, conn.get('stat:failed').to_i
        assert_equal 3, conn.get('stat:processed').to_i
      end
    end

    
    it 'updates global stats in the error case' do
      msg = Stompkiq.dump_json({ :class => DumbWorker.to_s, :args => [nil] })
      boss = MiniTest::Mock.new

      @redis.with do |conn|
        assert_equal [], conn.smembers('workers')
        assert_equal 0, conn.get('stat:failed').to_i
        assert_equal 0, conn.get('stat:processed').to_i

        processor = Stompkiq::Processor.new(boss)

        pstr = processor.to_s
        assert_raises RuntimeError do
          processor.process(msg, 'xyzzy')
        end

        assert_equal 1, conn.get('stat:failed').to_i
        assert_equal 1, conn.get('stat:processed').to_i
      end
    end

  end
end
