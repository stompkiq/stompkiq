require 'redis'
require 'multi_json'
require 'stomp'

module EventSource
  class EventLogger
    def initialize
      @stomp = Stomp::Client.new "admin", "password", "127.0.0.1", 61613
    end

    def queue_name
      "/queue/event_source:log"
    end

    def log_event(event_message)
      @stomp.publish queue_name, event_message
    end
  end
end

