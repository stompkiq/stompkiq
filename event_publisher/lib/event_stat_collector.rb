require 'stomp'
require 'logging'
require 'configuration'
require_relative 'config/statcollector'
require_relative '../common/enum_stats'
require 'redis'
require 'multi_json'

module EventSource
  # - Calculates statistics for a job
  # - Records them logfile
  class EventStatCollector
    attr_accessor :active_workers, :stats
    
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

      @active_workers = {}

      @stats = Hash.new {|hash,key| hash[key] = {mean_runtime: 0, run_times: [], run_count: 0, success_count: 0, error_count: 0, total_runtime: 0} }
      @redis = Redis.new
    end

    def start
      @stomp = Stomp::Client.new(@config.bus_username, @config.bus_password, @config.bus_location, @config.bus_port)
      @stomp.subscribe(@config.topic_to_listen_to) { |msg|
        handle_message msg.headers['destination'], msg.body
      }
      sleep 5 while true
    end
    
    def handle_message(topic, message)
      @log.info "Topic: #{topic}; Message: #{message}"

      msg = MultiJson.load message, symbolize_keys: true

      if msg[:event_name] == "StompkiqProcessorAssigned"
        handle_assign_message msg
      elsif msg[:event_name] == "StompkiqProcessorCompleted"
        handle_complete_message msg
      end
    end

    def handle_assign_message(msg)
      # TODO: Need a way to ever delete keys from this hash, else it
      # will keep growing in memory until this worker is restarted
      #
      # ANSWER: handle_complete_message should erase them. You can get
      # multiple runtimes if the process crashes/fails several times
      # before crashing
      @active_workers[active_worker_key msg] = msg
    end
    
    def handle_complete_message(msg)
      start_message = @active_workers[active_worker_key msg]

      # TODO: is it possible to ever update stats[:error_count]? This
      # is currently the  only method that creates/updates stats, and
      # it has a hard-coded true for errors
      # ANSWER: there should be a handle_error_message() that would do
      # this
      update_stats_for_class start_message[:message_class].to_sym, start_message, msg, true
    end

    def redis_stats_key
      "EventStats"
    end
    
    def active_worker_key(msg)
      # TODO: Make sure this stays unique if we run multiple stompkiqs
      # on a single server. If it doesn't, either find a way to
      # uniquify this or document that we can't run multiple stompkiqs
      { machine_name: msg[:machine_name], processor: msg[:processor] }
    end

    def update_stats_for_class(class_symbol, start_msg, end_msg, run_success)
      # This assumes that this object is the only source of changes to the stats in Redis.
      # dbrady notes: Redis gives us an inc method that would let us
      # get around this concern. We'd lose the ability to update this
      # as a single structure (e.g. atomically, as if it were in a
      # "transaction") but something to consider
      class_stats = @stats[class_symbol]
      runtime = end_msg[:time] - start_msg[:time]
      class_stats[:run_times] << runtime
      class_stats[:runtime_mean] = class_stats[:run_times].mean
      class_stats[:runtime_stdev] = class_stats[:run_times].length > 1? class_stats[:run_times].standard_deviation : 0
      class_stats[:run_count] += 1
      class_stats[:success_count] += 1 if run_success
      class_stats[:error_count] += 1 unless run_success
      class_stats[:total_runtime] += runtime
      #      puts class_stats
      @redis.hset redis_stats_key, class_symbol,  MultiJson.dump(class_stats)
    end


      
      # by Worker Class
      #   num of calls
      #   num successful
      #   num errros
      #   total time
      #   mean time
      #   standard deviation
      #   detailed run entries
      #       processor id, machine name
      #       start time
      #       end time
      #       run time



#      Dest: /topic/event_source:StompkiqProcessorAssigned; Body: {"event_name":"StompkiqProcessorAssigned","time":1344970617337,"machine_name":"ip-10-114-9-54","processor":5737300,"free_processors":24,"total_processors":25,"queue":"/queue/default","message_class":"EventSourceExampleWorker"}
#      Dest: /topic/event_source:StompkiqProcessorDied; Body: {"event_name":"StompkiqProcessorDied","time":1344970619382,"machine_name":"ip-10-114-9-54","processor":5737300,"free_processors":24,"total_processors":25,"reason":"undefined method `raise_event' for Stompkiq::Worker:Module"}

    #      Dest: /topic/event_source:StompkiqProcessorAssigned; Body: {"event_name":"StompkiqProcessorAssigned","time":1344970871691,"machine_name":"ip-10-114-9-54","processor":5526320,"free_processors":24,"total_processors":25,"queue":"/queue/default","message_class":"EventSourceExampleWorker"}
#      Dest: /topic/event_source:StompkiqProcessorCompleted; Body: {"event_name":"StompkiqProcessorCompleted","time":1344970874754,"machine_name":"ip-10-114-9-54","processor":5526320,"free_processors":24,"total_processors":25}


      
      #      Dest: /topic/event_source:StompkiqServiceStart; Body: {"event_name":"StompkiqServiceStart","time":1344970610456,"machine_name":"ip-10-114-9-54","processor_count":25,"queues":["/queue/default"],"options":{"queues":["/queue/default"],"concurrency":25,"require":"./event_publisher/example/event_source_example_worker.rb","environment":"development","timeout":8,"enable_rails_extensions":true}}
      #      Dest: /topic/event_source:StompkiqServiceShutdown; Body: {"event_name":"StompkiqServiceShutdown","time":1344970863820,"machine_name":"ip-10-114-9-54"}
      #      Dest: /topic/event_source:StompkiqServiceStart; Body: {"event_name":"StompkiqServiceStart","time":1344970865588,"machine_name":"ip-10-114-9-54","processor_count":25,"queues":["/queue/default"],"options":{"queues":["/queue/default"],"concurrency":25,"require":"./event_publisher/example/event_source_example_worker.rb","environment":"development","timeout":8,"enable_rails_extensions":true}}

  end
end

if __FILE__ == $0
  collector = EventSource::EventStatCollector.new
  collector.start
end

