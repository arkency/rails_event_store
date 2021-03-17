require "logger"
require "active_record"

module RubyEventStore
  module PersistentProjections
    class ProjectionStatus < ActiveRecord::Base
      self.table_name = 'event_store_projections'
    end

    class Event < ActiveRecord::Base
      self.table_name = 'event_store_events'
    end

    class Consumer
      SLEEP_TIME_WHEN_NOTHING_TO_DO = 0.1
      GLOBAL_POSITION_NAME = "$"

      def initialize(consumer_uuid, require_file, clock: Time, logger:)
        @clock = clock
        @logger = logger
        @consumer_uuid = consumer_uuid

        @gracefully_shutting_down = false
        prepare_traps

        require require_file unless require_file.nil?
      end

      def init
        logger.info("Initiated RubyEventStore::PersistentProjections v#{VERSION}")
        ActiveRecord::Base.connection.execute("SET SESSION innodb_lock_wait_timeout = 1;")
      end

      def run
        while !@gracefully_shutting_down do
          was_something_changed = one_loop
          if !was_something_changed
            STDOUT.flush
            sleep SLEEP_TIME_WHEN_NOTHING_TO_DO
          end
        end
        logger.info "Gracefully shutting down"
      end

      def one_loop
        last_id = Event.order("id DESC").first&.id || 0
        current_status = begin
          ProjectionStatus.find_by!(name: GLOBAL_POSITION_NAME)
        rescue ActiveRecord::RecordNotFound
          begin
            ProjectionStatus.create!(name: GLOBAL_POSITION_NAME, position: 0)
          rescue ActiveRecord::RecordNotUnique
            ProjectionStatus.find_by(name: GLOBAL_POSITION_NAME)
          end
        end
        return false if last_id == current_status.position
        next_position = current_status.position + 1
        begin
          check_event_on_position(next_position)
          bump_position_to_at_least(next_position)
        rescue ActiveRecord::RecordNotFound
          bump_position_to_at_least(next_position)
        rescue ActiveRecord::LockWaitTimeout
          logger.debug "Lock wait timeout"
        end
        true
      end

      def check_event_on_position(position)
        Event.transaction do
          ProjectionStatus.connection.execute("SELECT id FROM event_store_events WHERE id = #{position} FOR UPDATE")
        end
      end

      def bump_position_to_at_least(new_position)
        ProjectionStatus.connection.execute("UPDATE event_store_projections SET position = GREATEST(#{new_position}, position) WHERE name = '#{GLOBAL_POSITION_NAME}'")
        logger.debug "Progressed to at least #{new_position}"
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
