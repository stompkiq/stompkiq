require 'stompkiq/client'
require 'stompkiq/core_ext'
require 'stompkiq/event_sink'

module Stompkiq

  ##
  # Include this module in your worker class and you can easily create
  # asynchronous jobs:
  #
  # class HardWorker
  #   include Stompkiq::Worker
  #
  #   def perform(*args)
  #     # do some work
  #   end
  # end
  #
  # Then in your Rails app, you can do this:
  #
  #   HardWorker.perform_async(1, 2, 3)
  #
  # Note that perform_async is a class method, perform is an instance method.
  module Worker
    def self.included(base)
      base.extend(ClassMethods)
      base.class_attribute :stompkiq_options_hash
    end

    def logger
      Stompkiq.logger
    end

    # add event sink code here
    def raise_event(event_name, options={})
      Stompkiq::EventSink.raise_event(event_name, options)
    end
    
    module ClassMethods
      def perform_async(*args)
        client_push(:class => self, :args => args)
      end

      def perform_in(interval, *args)
        int = interval.to_f
        ts = (int < 1_000_000_000 ? Time.now.to_f + int : int)
        client_push(:class => self, :args => args, :at => ts)
      end
      alias_method :perform_at, :perform_in

      ##
      # Allows customization for this type of Worker.
      # Legal options:
      #
      #   :queue - use a named queue for this Worker, default 'default'
      #   :retry - enable the RetryJobs middleware for this Worker, default *true*
      #   :timeout - timeout the perform method after N seconds, default *nil*
      #   :backtrace - whether to save any error backtrace in the retry payload to display in web UI,
      #      can be true, false or an integer number of lines to save, default *false*
      def stompkiq_options(opts={})
        self.stompkiq_options_hash = get_stompkiq_options.merge(symbolize_keys(opts || {}))
      end

      # TODO: Add 'topic' => '/topic/default'
      DEFAULT_OPTIONS = { :retry => true, :queue => 'default', :queuetype => :queue }

      def get_stompkiq_options # :nodoc:
        self.stompkiq_options_hash ||= DEFAULT_OPTIONS
      end

      def symbolize_keys(hash) # :nodoc:
        hash.keys.each do |key|
          hash[key.to_sym] = hash.delete(key)
        end
        hash
      end

      def client_push(*args) # :nodoc:
        Stompkiq::Client.push(*args)
      end

      
    end
  end
end
