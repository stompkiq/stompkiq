require 'helper'
require 'stompkiq/scheduled'

class TestScheduling < MiniTest::Unit::TestCase
  describe 'middleware' do
    before do
      @redis = MiniTest::Mock.new
      # Ugh, this is terrible.
      Stompkiq.instance_variable_set(:@redis, @redis)

      def @redis.with; yield self; end
    end

    class ScheduledWorker
      include Stompkiq::Worker
      def perform(x)
      end
    end

    it 'schedules a job via interval' do
      @redis.expect :zadd, true, ['schedule', String, String]
      assert_equal true, ScheduledWorker.perform_in(600, 'mike')
      @redis.verify
    end

    it 'schedules a job via timestamp' do
      @redis.expect :zadd, true, ['schedule', String, String]
      assert_equal true, ScheduledWorker.perform_in(5.days.from_now, 'mike')
      @redis.verify
    end
  end

end
