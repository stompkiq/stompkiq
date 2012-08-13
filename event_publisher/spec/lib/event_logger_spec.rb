require 'spec_helper'
require 'redis'

module EventSource
  describe EventLogger do
    it "is sane" do
      # "cockroach spec"--opposite of a "canary spec", this spec is
      # "very hard to kill". If this spec fails it means your whole spec
      # suite has much, much bigger problems than you think
      42.should == 42
    end

    it "is defined" do
      EventLogger.should_not be_nil
    end

    describe "#log_event" do
      before :each do
        @stomp = double('stomp')
        Stomp::Client.stub(:new) {@stomp}
      end
      
      it "can log an event" do
        msg = "{\"event_name\":\"TestEvent\",\"time\":#{Time.now.to_i}}"
        @stomp.should_receive(:publish).with("/queue/event_source:log", msg)
        @event_logger = EventLogger.new 
        @event_logger.log_event(msg)
      end
    end
    
  end
end
