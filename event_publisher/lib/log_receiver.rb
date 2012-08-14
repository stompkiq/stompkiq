require 'logging'
require 'stomp'
require 'configuration'
require_relative 'config/logrec'

module EventSource
  class LogReceiver

    def initialize(options={})
      @config = Configuration.for('logreceiver')
      
      @log = Logging.logger["EventSourceLogger"]
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
    
    def handle_message(message)
      @log.info(message)
    end

    def listen_for_messages
      @stomp = Stomp::Client.new(@config.bus_username, @config.bus_password, @config.bus_location, @config.bus_port)
      @stomp.subscribe(@config.bus_queue_for_log_events) {|msg| handle_message(msg.body)}

      while true
        sleep 5
      end
    end
 
  end
end


if __FILE__ == $0
  logreceiver = EventSource::LogReceiver.new
  logreceiver.listen_for_messages
end

