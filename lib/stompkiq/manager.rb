require 'celluloid'

require 'stompkiq/util'
require 'stompkiq/processor'
require 'stompkiq/version'

module Stompkiq

  ##
  # The main router in the system.  This
  # manages the processor state and accepts messages
  # from Redis to be dispatched to an idle processor.
  #
  class Manager
    include Util
    include Celluloid

    trap_exit :processor_died

    def initialize(options={})
      logger.info "Booting stompkiq #{Stompkiq::VERSION} with Redis at #{redis {|x| x.client.id}}"
      logger.info "Running in #{RUBY_DESCRIPTION}"
      logger.debug { options.inspect }
      @count = options[:concurrency] || 25
      @done_callback = nil

      @event_origination = options[:event_origination]
      @event_origination = true if @event_origination.nil?
      @in_progress = {}
      @done = false
      @busy = []
      @queues = options[:queues]
      @ready = @count.times.map { Processor.new_link(current_actor) }
      procline
      EventSink.raise_event("StompkiqServiceStart", machine_name: Socket.gethostname, processor_count: @ready.size, queues: @queues,  options: options)
    end

    def stop(options={})
      watchdog('Manager#stop died') do
        shutdown = options[:shutdown]
        timeout = options[:timeout]
        
        EventSink.raise_event("StompkiqServiceShutdown", machine_name: Socket.gethostname)

        @done = true

        logger.info { "Shutting down #{@ready.size} quiet workers" }
        @ready.each { |x| x.terminate if x.alive? }
        @ready.clear

        logger.debug { "Clearing workers in redis" }
        Stompkiq.redis do |conn|
          workers = conn.smembers('workers')
          workers.each do |name|
            conn.srem('workers', name) if name =~ /:#{process_id}-/
          end
        end

        Stompkiq.stomp do |conn|
          @queues.uniq.each do |q|
            conn.unsubscribe(q)
          end
        end
        

        return after(0) { signal(:shutdown) } if @busy.empty?
        logger.info { "Pausing up to #{timeout} seconds to allow workers to finish..." }
        hard_shutdown_in timeout if shutdown
      end
    end

    def start

      @queues.each do |q|
        subscribe q
      end
    end

    def when_done(&blk)
      @done_callback = blk
    end

    def processor_done(processor)
      watchdog('Manager#processor_done died') do
        @done_callback.call(processor) if @done_callback

        if @event_origination
          EventSink.raise_event("StompkiqProcessorCompleted", machine_name: Socket.gethostname, processor: processor.object_id, free_processors: @ready.length, total_processors: @ready.length + @busy.length)
        end
        
        @in_progress.delete(processor.object_id)
        @busy.delete(processor)
        if stopped?
          processor.terminate if processor.alive?
          signal(:shutdown) if @busy.empty?
        else
          @ready << processor if processor.alive?
        end
      end
    end

    def processor_died(processor, reason)
      watchdog("Manager#processor_died died") do

        if @event_origination && !stopped? 
          EventSink.raise_event("StompkiqProcessorDied", machine_name: Socket.gethostname, processor: processor.object_id, free_processors: @ready.length, total_processors: @ready.length + @busy.length, reason: reason)
        end
        
        
        @in_progress.delete(processor.object_id)
        @busy.delete(processor)

        unless stopped?
          @ready << Processor.new_link(current_actor)
        else
          signal(:shutdown) if @busy.empty?
        end
      end
    end

    def assign(msg, queue, klass)
      watchdog("Manager#assign died") do
        # This works but it's a hack.  Need more elegant way to block if the ready queue is empty.
        # Also need to check for stopped? and requeue if so

        processor = nil
        sleep 1 until stopped? || processor = @ready.pop

        if processor
          @in_progress[processor.object_id] = [msg, queue]
          @busy << processor

          if @event_origination
            klass  = constantize(Stompkiq.load_json(msg)[:class])
            EventSink.raise_event("StompkiqProcessorAssigned", machine_name: Socket.gethostname, processor: processor.object_id, free_processors: @ready.length, total_processors: @ready.length + @busy.length, queue: queue, message_class: klass.to_s)
          end
          
          
          processor.process!(msg, queue)
        else
          # We need to requeue.
          # Race condition between Manager#stop if Fetcher
          # is blocked on redis and gets a message after
          # all the ready Processors have been stopped.
          # Push the message back to redis.
          Stompkiq.stomp do |conn|
            conn.publish(queue, msg)
          end
        end

      end
      
    end

    def wait_for_free_processor
      sleep 1
      stopped?
    end
    

    private

    def hard_shutdown_in(delay)
      after(delay) do
        watchdog("Manager#watch_for_shutdown died") do
          # We've reached the timeout and we still have busy workers.
          # They must die but their messages shall live on.
          logger.info("Still waiting for #{@busy.size} busy workers")

          Stompkiq.stomp do |conn|
            @busy.each do |processor|
              # processor is an actor proxy and we can't call any methods
              # that would go to the actor (since it's busy).  Instead
              # we'll use the object_id to track the worker's data here.
              msg, queue = @in_progress[processor.object_id]
              conn.publish(queue, msg)
            end
            
          end
          logger.info("Pushed #{@busy.size} messages back to Apollo")

          
          after(0) { signal(:shutdown) }
        end
      end
    end

    def subscribe(queue_name)
      Stompkiq.stomp do |conn|
        conn.subscribe(queue_name) do  |msg|
          assign(msg.body, msg.headers['destination'], msg.headers['klass'])
        end
        
      end
    end
    
    def stopped?
      @done
    end

    def procline
      $0 = "stompkiq #{Stompkiq::VERSION} [#{@busy.size} of #{@count} busy]#{stopped? ? ' stopping' : ''}"
      after(5) { procline }
    end
  end
end
