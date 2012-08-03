require 'stompkiq'
require 'stompkiq/util'
require 'celluloid'

module Stompkiq
  module Scheduled

    POLL_INTERVAL = 15

    ##
    # The Poller checks Redis every N seconds for messages in the retry or scheduled
    # set have passed their timestamp and should be enqueued.  If so, it
    # just pops the message back onto its original queue so the
    # workers can pick it up like any other message.
    class Poller
      include Celluloid
      include Stompkiq::Util

      SETS = %w(retry schedule)

      def poll(first_time=false)
        watchdog('scheduling poller thread died!') do
          add_jitter if first_time

          begin
            # A message's "score" in Redis is the time at which it should be processed.
            # Just check Redis for the set of messages with a timestamp before now.
            now = Time.now.to_f.to_s
            Stompkiq.redis do |conn|
              SETS.each do |sorted_set|
                (messages, _) = conn.multi do
                  conn.zrangebyscore(sorted_set, '-inf', now)
                  conn.zremrangebyscore(sorted_set, '-inf', now)
                end

                messages.each do |message|
                  logger.debug { "enqueued #{sorted_set}: #{message}" }
                  msg = Stompkiq.load_json(message)
                  conn.multi do
                    conn.sadd('queues', msg[:queue])
                    conn.rpush("queue:#{msg[:queue]}", message)
                  end
                end
              end
            end
          rescue SystemCallError => ex
            # ECONNREFUSED, etc.  Most likely a problem with
            # redis networking.  Punt and try again at the next interval
            logger.warn ex.message
          end

          after(poll_interval) { poll }
        end
      end

      private

      def poll_interval
        Stompkiq.options[:poll_interval] || POLL_INTERVAL
      end

      def add_jitter
        begin
          sleep(poll_interval * rand)
        rescue Celluloid::Task::TerminatedError
          # Hit Ctrl-C when Stompkiq is finished booting and we have a chance
          # to get here.
        end
      end

    end
  end
end
