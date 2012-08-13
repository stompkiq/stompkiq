require 'spec_helper'
require 'redis'

module EventSource
  describe EventPublisher do
    it "is sane" do
      # "cockroach spec"--opposite of a "canary spec", this spec is
      # "very hard to kill". If this spec fails it means your whole spec
      # suite has much, much bigger problems than you think
      42.should == 42
    end

    it "is defined" do
      EventPublisher.should_not be_nil
    end

    describe "#poll" do
      before :each do
        @stomp = double('stomp')
        Stomp::Client.stub(:new) {@stomp}
      end
      
      it "can broadcast an event" do
        msg = "{\"event_name\":\"TestEvent\",\"time\":#{Time.now.to_i}}"
        @stomp.should_receive(:publish).with("/topic/event_source:TestEvent", msg)
        @event_publisher = EventPublisher.new #(@redis)
        @event_publisher.publish_event(msg)
      end
    end
    
  end
end
