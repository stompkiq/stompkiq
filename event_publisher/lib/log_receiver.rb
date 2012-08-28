require 'logging'
require 'stomp'
require 'configuration'
require_relative 'config/logrec'
require_relative 'config/dbconfig'
require 'multi_json'
require 'active_record'
require 'uuidtools'

# Today's Handy Emacs Navigation Tips:
#
# C-v PageDn
# M-v PageUp
# M-< Go to BOF
# M-> Go to EOF
# C-l Center current line on page
#
# BONUS PROTIP:
# C-u X C-l Center page so that current line is at line X

db_config = Configuration.for('event_publisher_long_term_storage')
ActiveRecord::Base.establish_connection(
                                        database: db_config.db_name_event_source,
                                        host: db_config.db_server_name,
                                        port: db_config.db_port,
                                        # url: url,
                                        username: db_config.db_user_name,
                                        password: db_config.db_password,
                                        adapter: 'sqlserver'
                                        )

class EventPublisherLog < ActiveRecord::Base
  # serialize <column>, <LoaderClass>
  # -> before saving to the database, table.column = LoaderClass.dump(self.column)
  # -> after loading from the database, self.column = LoaderClass.load(table.column)
  # In this case, use MultiJson so that
  # 1. When we're in memory, we're a hash (a Ruby object that can be negotiated with)
  # 2. When we're in the database, we're a json string (e.g. a terrorist)
  serialize :event_data, MultiJson 

  # Before we save to the database the very first time, set our id
  # field to a guid. SQL Server gets absolutely BENT OUT OF SHAPE if
  # you try to pass SET id=NULL. IT'S CALLED FRICKING SQL-92 MORANS

 # commenting out this code for now.....
  before_create :create_guid

#  before_create :change_column_definition

  def change_column_definition
    change_column :event_publisher_logs, :id, :uniqueidentifier, :default => nil
  end
  # change_column :event_publisher_logs, :id, :uniqueidentifier, :default => nil
  # alias_attribute :id
  
  # id
  # event_name
  # event_time
  # event_log_item VARCHAR(500) <-- drop this column
  # event_data VARCHAR(MAX) # your mom fits in here (almost)
  # log_level VARCHAR(10) # one of 'INFO', 'DEBUG', 'ERROR', 'FATAL'
  # created_at DATETIME

  def self.parse(message)
    json = MultiJson.load(message)
    event_name = json["event_name"]
    event_time = Time.at(json["time"]/1000.0).strftime("%Y-%m-%d %H:%M:%S.%L")
    
    new event_name: event_name, event_time: event_time, event_data: json, log_level: 'INFO'
  end

  def create_guid
    self.id ||= UUIDTools::UUID.random_create.to_s
  end
end

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
      begin
        @log.info "I HAVE THE MOST AMAZING HAT"
        @log.info(message)
        # Need to save to database instead of logfile?
        event = EventPublisherLog.parse message
        event.save
        @log.debug "LogReceiver: saved event! #{!!event.new_record?}"
        @log.info "A WINNER IS ME!!!"
      rescue Exception => e
        @log.error "I CAN'T FEEL THE RIGHT SIDE OF MY BODY"
        @log.error "Hey reemmber when Dave went all ape-poo about not catching Exception? Yeah. SHUT UP."
        @log.error "Here's what wreng. WReng? WENT WRONG AND STUFF."
        @log.error e.inspect
        @log.error "Here endeth the lesson."
      end
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

