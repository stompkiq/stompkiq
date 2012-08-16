require 'stomp'
require 'logging'
require 'configuration'
require_relative 'config/statcollector'
require_relative '../common/enum_stats'
require 'redis'
require 'multi_json'

module EventSource
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
      @stats = {}
      @redis = Redis.new
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

      begin
        msg = MultiJson.load message, symbolize_keys: true

        if msg[:event_name] == "StompkiqProcessorAssigned"
          handle_assign_message(msg)
        elsif msg[:event_name] == "StompkiqProcessorCompleted"
          handle_complete_message(msg)
        end
      rescue Exception => e
        @log.info e
      end
      
    end

    def handle_assign_message(msg)
      @active_workers[active_worker_key msg ] = msg
    end
    
    def handle_complete_message(msg)
      # @log.info "msg: #{msg}"
      # @log.info "key: #{active_worker_key msg}"
      # @log.info "active_workers: #{@active_workers}"
      start_message = @active_workers[active_worker_key msg]

      compute_stats_for_class(start_message[:message_class].to_sym, start_message, msg, true)
    end

    def redis_stats_key
      "EventStats"
    end
    

    def compute_stats_for_class(class_symbol, start_msg, end_msg, run_success)
      # This assumes that this object is the only source of changes to the stats in Redis.
      class_stats = class_stats(class_symbol)
      runtime = end_msg[:time] - start_msg[:time]
      class_stats[:run_times] << runtime
      class_stats[:runtime_mean] = class_stats[:run_times].mean
      class_stats[:runtime_stdev] = class_stats[:run_times].length > 1? class_stats[:run_times].standard_deviation : 0
      class_stats[:run_ct] += 1
      class_stats[:success_ct] += 1 if run_success
      class_stats[:error_ct] += 1 unless run_success
      class_stats[:total_runtime] += runtime
#      puts class_stats
      @redis.hset redis_stats_key, class_symbol,  MultiJson.dump(class_stats)
    end

    def class_stats(class_symbol)
      init_stats_for_class class_symbol unless @stats.include? class_symbol

      @stats[class_symbol]
    end
    
    def init_stats_for_class(class_symbol)
      unless @stats.include? class_symbol
        @stats[class_symbol] = {mean_runtime: 0, run_times: [], run_ct: 0, success_ct: 0, error_ct: 0, total_runtime: 0}
      end
    end
    

    def active_worker_key(msg)
      { machine_name: msg[:machine_name], processor: msg[:processor] }
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

