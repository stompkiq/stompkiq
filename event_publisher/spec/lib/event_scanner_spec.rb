require 'spec_helper'
require 'redis'

describe EventSource::EventScanner do
  it "is sane" do
    # "cockroach spec"--opposite of a "canary spec", this spec is
    # "very hard to kill". If this spec fails it means your whole spec
    # suite has much, much bigger problems than you think
    42.should == 42
  end

  it "is defined" do
    EventSource::EventScanner.should_not be_nil
  end

  describe "#poll" do
    before :each do
      @redis = double('redis')
      Redis.stub(:new) {@redis}
      # @redis = Redis.new
      # @redis.del "Stompkiq:LocalEvents"
    end

    
    it "can pull a message from redis" do
      msg = "{\"event_name\":\"TestEvent\",\"time\":#{Time.now.to_i}}"
      @redis.should_receive(:blpop).and_return(["Stompkiq:LocalEvents", msg])
      # @redis.rpush "Stompkiq:LocalEvents", "foo"
      @event_scanner = EventSource::EventScanner.new #(@redis)
      @event_scanner.pull_local_event_from_redis.should =~ ["Stompkiq:LocalEvents", msg]
    end
  end

  
end
