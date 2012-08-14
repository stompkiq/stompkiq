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
        @fail_assign_msg = '{"event_name":"StompkiqProcessorAssigned","time":1344970617337,"machine_name":"ip-10-114-9-54","processor":5737300,"free_processors":24,"total_processors":25,"queue":"/queue/default","message_class":"EventSourceExampleWorker"}'
        @fail_die_msg = '{"event_name":"StompkiqProcessorDied","time":1344970619382,"machine_name":"ip-10-114-9-54","processor":5737300,"free_processors":24,"total_processors":25,"reason":"undefined method `raise_event\' for Stompkiq::Worker:Module"}'

        @success_assign_msg = '{"event_name":"StompkiqProcessorAssigned","time":1344970871691,"machine_name":"ip-10-114-9-54","processor":5526320,"free_processors":24,"total_processors":25,"queue":"/queue/default","message_class":"EventSourceExampleWorker"}'
        @success_complete_msg = '{"event_name":"StompkiqProcessorCompleted","time":1344970874754,"machine_name":"ip-10-114-9-54","processor":5526320,"free_processors":24,"total_processors":25}'

        @assign_topic = "/topic/event_source:StompkiqProcessorAssigned"
        @complete_topic = "/topic/event_source:StompkiqProcessorCompleted"
        @fail_topic = "/topic/event_source:StompkiqProcessorDied"
        
        @logger = double('logger')
        Logging.stub(:logger) {@logger}
        @logger.stub(:add_appenders)
        @logger.stub(:appenders).and_return([])
        @logger.stub(:[]).and_return(@logger)
        @logger.stub(:level=)
        @logger.stub(:info)
        
        @collector = EventStatCollector.new

      end
      
      it "identify processor assigned message" do
        @collector.should_receive(:handle_assign_message)
        @collector.handle_message(@assign_topic, @success_assign_msg)
      end

      it "identify processor complete message" do
        @collector.should_receive(:handle_complete_message)
        @collector.handle_message(@complete_topic, @success_complete_msg)
      end

      describe "successful process flow" do
        before :each do
          @collector.handle_message(@assign_topic, @success_assign_msg)
        end

        it "creates the correct hash key for a message" do
          msg = MultiJson.load @success_assign_msg, symbolize_keys: true
          rslt = @collector.active_worker_key msg
          rslt.should == {machine_name: "ip-10-114-9-54", processor: 5526320}
        end


        it "caches process start upon assign" do
          @collector.active_workers.should be_include machine_name: "ip-10-114-9-54", processor: 5526320
        end
        
        it "computes average run time for a single execution" do
          @collector.handle_message(@complete_topic, @success_complete_msg)
          @collector.stats[:EventSourceExampleWorker][:runtime_mean].should == 3063
        end
      end
      
      
    end
     
  end
end
