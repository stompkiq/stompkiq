require 'helper'
require 'stompkiq/processor'

class TestProcessor < MiniTest::Unit::TestCase
  describe 'with mock setup' do
    before do
      $invokes = 0
      $errors = []
      @boss = MiniTest::Mock.new
      Celluloid.logger = nil
      Stompkiq.redis = REDIS
    end

    class MockWorker
      include Stompkiq::Worker
      def perform(args)
        raise "kerboom!" if args == 'boom'
        $invokes += 1
      end
    end

    it 'processes as expected' do
      msg = Stompkiq.dump_json({ :class => MockWorker.to_s, :args => ['myarg'] })
      processor = ::Stompkiq::Processor.new(@boss)
      @boss.expect(:processor_done!, nil, [processor])
      processor.process(msg, 'default')
      @boss.verify
      assert_equal 1, $invokes
      assert_equal 0, $errors.size
    end
  end
end
