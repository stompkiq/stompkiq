require 'spec_helper'
require 'redis'

module EventSource

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

    describe "test methods" do
      before :each do
        @redis = double('redis')
        Redis.stub(:new) {@redis}

        @msg = "{\"event_name\":\"TestEvent\",\"time\":#{Time.now.to_i}}"

        @publisher = double('publisher')
        EventPublisher.stub(:new) { @publisher }

        @logger = double('logger')
        EventLogger.stub(:new) { @logger }

        @event_scanner = EventScanner.new

      end

      describe "#pull_local_event_from_redis" do

        it "can pull a message from redis" do
          @redis.should_receive(:blpop).and_return(["Stompkiq:LocalEvents", @msg])
          @event_scanner.pull_local_event_from_redis.should =~ ["Stompkiq:LocalEvents", @msg]
        end
      end

      describe "#publish_event" do

        it "can publish an event" do
          @publisher.should_receive(:publish_event).with(@msg)
          @event_scanner.publish_event(@msg)
        end
      end

      describe "#log_event" do

        it "can log an event" do
          @logger.should_receive(:log_event).with(@msg)
          @event_scanner.log_event(@msg)
        end
      end

      describe "#broadcast_event" do

        it "broadcast an event" do
          @publisher.should_receive(:publish_event).with(@msg)
          @logger.should_receive(:log_event).with(@msg)
          @event_scanner.broadcast_event(@msg)
        end
      end

      class JumpOutOfTheLoop < Exception
      end
      
      describe "#detect_and_broadcast_events" do
        it "detects and publishes events" do
          @publisher.should_receive(:publish_event).with(@msg)

          the_exception = JumpOutOfTheLoop.new(:reason => :done_testing)
          @logger.should_receive(:log_event).with(@msg).and_raise(the_exception)

          @redis.should_receive(:blpop).and_return(["Stompkiq:LocalEvents", @msg])

          begin
            @event_scanner.detect_and_broadcast_events
          rescue JumpOutOfTheLoop
            
          end
          
        end
      end

    end    
  end
end
