require 'redis'
require 'event_publisher'
require 'event_logger'

module EventSource
  class EventScanner

    def initialize(redis=nil)
      @redis = redis ||= Redis.new
      # @publisher = EventPublisher.new
      # @logger = EventLogger.new
    end

    def pull_local_event_from_redis
      @redis.blpop "Stompkiq:LocalEvents"
    end

    def detect_and_broadcast_events
      while true do
        _, message = pull_local_event_from_redis
        broadcast_event message if message
      end
    end

    def broadcast_event(message)
      publish_event message
      log_event message
    end
    
    def publish_event(message)
      @publisher.publish_event message
    end

    def log_event(message)

      @logger.log_event message
    end
  end
end
