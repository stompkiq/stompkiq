require 'stomp'
require 'logging'
require 'configuration'
require_relative 'config/statcollector'

module EventSource
  class EventStatCollector
    
    def initialize
      @config = Configuration.for('stat_collector')
      
      @log = Logging.logger["EventSourceStatCollector"]
      @log.add_appenders(
                         Logging.appenders.stdout,
                         Logging.appenders.rolling_file(
                                                        "#{@config.logdir}/#{@config.logfilename}",
                                                        :age => 'daily',
                                                        :layout => Logging.layouts.pattern(:pattern => '[%d] (%p:%T) %-5l: %m\n')
                                                        )
                         ) if @log.appenders.count == 0

      @log.level = :info
    end

    def start
      @stomp = Stomp::Client.new(@config.bus_username, @config.bus_password, @config.bus_location, @config.bus_port)
      @stomp.subscribe( @config.topic_to_listen_to) { |msg|
        handle_message(msg.headers['destination'], msg.body)
      }
      while true
        sleep 5
      end
    end
    
    def handle_message(topic, message)
      @log.info "Topic: #{topic}; Message: #{message}"
    end
  end
end

if __FILE__ == $0
  collector = EventSource::EventStatCollector.new
  collector.start
end

