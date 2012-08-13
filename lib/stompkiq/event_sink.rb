require 'multi_json'
require 'stompkiq'

module Stompkiq
  class EventSink

    def self.raise_event(event_name, options={})
      msg = MultiJson.dump({event_name: event_name || "UnknownEvent", time: (Time.now.to_f * 1000.0).to_i}.merge(options))
      Stompkiq.redis {|x| x.rpush("Stompkiq:LocalEvents", msg) > 0 }
    end

  end

  
  
end
