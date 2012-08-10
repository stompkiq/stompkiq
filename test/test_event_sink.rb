require 'helper'
require 'stompkiq/event_sink'

class TestEventSink < MiniTest::Unit::TestCase
  describe "with mock redis and mock stomp" do
    before do
      @redis = MiniTest::Mock.new
      def @redis.with; yield self; end
      # def @redis.exec; true; end
      Stompkiq.instance_variable_set(:@redis, @redis)
    end


    it "does something" do
      
    end

    it 'exists' do
      assert Stompkiq::EventSink != nil 
    end

    #  describe ".new" do
    # it "initializes an event sink" do
    
    # end
    #  end

    describe "define raise event" do
      it "raises an event" do
        @redis.expect :rpush, 1, [String, String]
        assert Stompkiq::EventSink.raise_event event_name: :TestEvent
        @redis.verify
      end

      it "sends event name to redis" do
        @redis.expect :rpush, 1, ["Stompkiq:LocalEvents", "{\"event_name\":\"TestEvent\",\"time\":#{Time.now.to_i}}"]
        assert Stompkiq::EventSink.raise_event event_name: :TestEvent
        @redis.verify
      end

      it "sends event details to redis" do
        @redis.expect :rpush, 1, ["Stompkiq:LocalEvents", "{\"event_name\":\"TestEvent\",\"time\":#{Time.now.to_i},\"foo\":3}"]
        assert Stompkiq::EventSink.raise_event event_name: :TestEvent, foo: 3 
        @redis.verify
      end

    end

  end




end
