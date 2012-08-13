require 'redis'
require 'multi_json'
require 'stomp'

module EventSource
  class EventPublisher

    def initialize
      @stomp = Stomp::Client.new "admin", "password", "127.0.0.1", 61613
    end

    def broadcast_event(event_message)
      decoded_message = MultiJson.load message
      @stomp.publish "/topic/event_source:#{decoded_message[:event_name]}", message
    end
    
  end
end
