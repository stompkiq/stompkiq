require 'spec_helper'
require 'logging'

module EventSource
  describe LogReceiver do
    it "is sane" do
      # "cockroach spec"--opposite of a "canary spec", this spec is
      # "very hard to kill". If this spec fails it means your whole spec
      # suite has much, much bigger problems than you think
      42.should == 42
    end

    it "is defined" do
      LogReceiver.should_not be_nil
    end

    describe "#handle_message" do
      before :each do
        @logger = double('logger')
        Logging.stub(:logger) {@logger}
        @logger.stub(:add_appenders)
        @logger.stub(:appenders).and_return([])
        @logger.stub(:[]).and_return(@logger)
        @logger.stub(:level=)
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
