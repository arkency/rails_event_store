require "active_record"

module RubyEventStore
  module PersistentProjections
    class GlobalUpdater
      class ProjectionStatus < ActiveRecord::Base
        self.table_name = 'event_store_projections'
      end

      class Event < ActiveRecord::Base
        self.table_name = 'event_store_events'
      end

      GLOBAL_POSITION_NAME = "$"

      def initialize(logger:, clock:)
        @logger = logger
        @clock = clock
      end

      def init
        if ActiveRecord::Base.connection.adapter_name == "Mysql2"
          ActiveRecord::Base.connection.execute("SET SESSION innodb_lock_wait_timeout = 1;")
        end
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

      attr_reader :logger, :clock
    end
  end
end
