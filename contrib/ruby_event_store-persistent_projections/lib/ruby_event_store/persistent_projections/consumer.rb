require "logger"
require "active_record"
require "ruby_event_store/persistent_projections/global_updater"

module RubyEventStore
  module PersistentProjections
    class Consumer
      SLEEP_TIME_WHEN_NOTHING_TO_DO = 0.1

      def initialize(consumer_uuid, require_file, clock: Time, logger:)
        @clock = clock
        @logger = logger
        @consumer_uuid = consumer_uuid

        @gracefully_shutting_down = false
        prepare_traps

        require require_file unless require_file.nil?

        @global_updater = GlobalUpdater.new(logger: logger, clock: clock)
      end

      def init
        logger.info("Initiated RubyEventStore::PersistentProjections v#{VERSION}")
        @global_updater.init
      end

      def run
        global_updater_thread = Thread.new do
          while !@gracefully_shutting_down do
            was_something_changed = @global_updater.one_loop
            if !was_something_changed
              STDOUT.flush
              sleep SLEEP_TIME_WHEN_NOTHING_TO_DO
            end
          end
        end
        while !@gracefully_shutting_down do
          sleep 1
        end
        logger.info "Waiting for threads to finish"
        [global_updater_thread].map(&:join)
        logger.info "Gracefully shutting down"
      end

      private
      attr_reader :logger

      def prepare_traps
        Signal.trap("INT") do
          initiate_graceful_shutdown
        end
        Signal.trap("TERM") do
          initiate_graceful_shutdown
        end
      end

      def initiate_graceful_shutdown
        @gracefully_shutting_down = true
      end
    end
  end
end
