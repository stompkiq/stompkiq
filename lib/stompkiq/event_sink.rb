require 'multi_json'
require 'stompkiq'

module Stompkiq
  class EventSink

    def self.raise_event(options={})
      msg = MultiJson.dump({event_name: options[:event_name] || "UnknownEvent", time: Time.now.to_i}.merge(options))
      puts msg
      Stompkiq.redis {|x| x.rpush("Stompkiq:LocalEvents", msg) > 0 }
    end

  end

  
  
end
