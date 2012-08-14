require 'spec_helper'

module EventSource
  describe EventStatCollector do
    it "is sane" do
      # "cockroach spec"--opposite of a "canary spec", this spec is
      # "very hard to kill". If this spec fails it means your whole spec
      # suite has much, much bigger problems than you think
      42.should == 42
    end

    it "is defined" do
      EventStatCollector.should_not be_nil
    end

    describe "#handle_message" do
      before :each do

      end
      
      it "handle a log event message by writing it to the log" do
        msg = "{\"event_name\":\"TestEvent\",\"time\":#{Time.now.to_i}}"
        # Need to mock a logger
        @logger.should_receive(:info).with(msg)
        @log_receiver = LogReceiver.new 
        @log_receiver.handle_message(msg)
      end
    end
     
  end
end
