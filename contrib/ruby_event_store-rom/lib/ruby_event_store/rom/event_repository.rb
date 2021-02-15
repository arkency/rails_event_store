# frozen_string_literal: true

require 'ruby_event_store/rom/unit_of_work'
require 'forwardable'

module RubyEventStore
  module ROM
    class EventRepository
      extend Forwardable

      def_delegator :@rom, :handle_error, :guard_for
      def_delegators :@rom, :unit_of_work

      def initialize(rom: ROM.env, serializer:)
        raise ArgumentError, 'Must specify rom' unless rom && rom.instance_of?(Env)

        @rom = rom
        @events = Repositories::Events.new(rom.rom_container)
        @stream_entries = Repositories::StreamEntries.new(rom.rom_container)
        @serializer = serializer
      end

      def append_to_stream(records, stream, expected_version)
        serialized_records = Array(records).map { |record| record.serialize(@serializer) }
        event_ids = serialized_records.map(&:event_id)

        guard_for(:unique_violation) do
          unit_of_work do |changesets|
            # Create changesets inside transaction because
            # we want to find the last position (a.k.a. version)
            # again if the transaction is retried due to a
            # deadlock in MySQL
            changesets << @events.create_changeset(serialized_records)
            changesets << @stream_entries.create_changeset(
              event_ids,
              stream,
              @stream_entries.resolve_version(stream, expected_version)
            )
          end
        end

        self
      end

      def link_to_stream(event_ids, stream, expected_version)
        event_ids = Array(event_ids)

        # Validate event IDs
        @events
          .find_nonexistent_pks(event_ids)
          .each { |id| raise EventNotFound, id }

        guard_for(:unique_violation) do
          unit_of_work do |changesets|
            changesets << @stream_entries.create_changeset(
              event_ids,
              stream,
              @stream_entries.resolve_version(stream, expected_version)
            )
          end
        end

        self
      end

      def delete_stream(stream)
        @stream_entries.delete(stream)
      end

      def has_event?(event_id)
        guard_for(:not_found, event_id, swallow: EventNotFound) { @events.exist?(event_id) } || false
      end

      def last_stream_event(stream)
        @events.last_stream_event(stream, @serializer)
      end

      def read(specification)
        @events.read(specification, @serializer)
      end

      def count(specification)
        @events.count(specification)
      end

      def update_messages(records)
        # Validate event IDs
        @events
          .find_nonexistent_pks(records.map(&:event_id))
          .each { |id| raise EventNotFound, id }

        unit_of_work do |changesets|
          serialized_records = records.map { |record| record.serialize(@serializer) }
          changesets << @events.update_changeset(serialized_records)
        end
      end

      def streams_of(event_id)
        @stream_entries.streams_of(event_id)
                       .map { |name| Stream.new(name) }
      end

      def inspect
        "#<#{self.class}:0x#{__id__.to_s(16)}>"
      end
    end
  end
end
