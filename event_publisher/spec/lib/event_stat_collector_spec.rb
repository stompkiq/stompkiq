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
        # WOOOOF.
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

        @redis = double('redis')
        Redis.stub(:new) {@redis}
        @redis.stub(:hset)
        @redis.stub(:hget).and_return("{\"mean_runtime\":0,\"run_times\":[3063],\"run_count\":1,\"success_count\":1,\"error_count\":0,\"total_runtime\":3063,\"runtime_mean\":3063.0,\"runtime_stdev\":0}")
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


      describe "#handle_assign_message" do
        it "records message in active_workers for later" do
          lambda { @collector.handle_message(@assign_topic, @success_assign_msg) }.should change { @collector.active_workers.size }.by(1)
        end
      end
      
      describe "#handle_complete_message" do
        # FIXME: Fragile. Crashes if we try to complete a message that
        # we haven't seen assigned. What if another worker gets the
        # assign and we get the complete? What if this worker crashes
        # and restarts, and we get a complete for which there is no
        # start message?
        before :each do
          @collector.handle_message @assign_topic, @success_assign_msg
        end

        it "updates stats" do
          lambda { @collector.handle_message(@complete_topic, @success_complete_msg) }.should change {@collector.stats[:EventSourceExampleWorker][:run_count] }.by(1)
        end
      end
      
      describe "successful process flow" do
        before :each do
          @collector.handle_message(@assign_topic, @success_assign_msg)
        end

        it "creates the correct hash key for a message" do
          msg = MultiJson.load @success_assign_msg, symbolize_keys: true
          result = @collector.active_worker_key msg
          result.should == {machine_name: "ip-10-114-9-54", processor: 5526320}
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
