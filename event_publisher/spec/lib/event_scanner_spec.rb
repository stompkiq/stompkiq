require 'spec_helper'
require 'redis'

describe EventScanner do
  it "is sane" do
    # "cockroach spec"--opposite of a "canary spec", this spec is
    # "very hard to kill". If this spec fails it means your whole spec
    # suite has much, much bigger problems than you think
    42.should == 42
  end

  it "is defined" do
    EventScanner.should_not be_nil
  end

  describe "#poll" do
    before :each do
      @redis = Redis.new
      @redis.del "Stompkiq:LocalEvents"
    end

    
    it "can pull a message from redis" do
      @redis.rpush "Stompkiq:LocalEvents", "foo"
      @event_scanner = EventScanner.new
      @event_scanner.pull_local_event_from_redis.should == ["Stompkiq:LocalEvents", "foo"]
    end
  end

  
end
