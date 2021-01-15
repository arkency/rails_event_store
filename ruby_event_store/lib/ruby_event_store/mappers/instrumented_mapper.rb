# frozen_string_literal: true

module RubyEventStore
  module Mappers
    class InstrumentedMapper
      def initialize(mapper, instrumentation)
        @mapper = mapper
        @instrumentation = instrumentation
      end

      def event_to_record(event)
        instrumentation.instrument("event_to_record.mapper.ruby_event_store", event: event) do
          mapper.event_to_record(event)
        end
      end

      def record_to_event(record)
        instrumentation.instrument("record_to_event.mapper.ruby_event_store", record: record) do
          mapper.record_to_event(record)
        end
      end

      private

      attr_reader :instrumentation, :mapper
    end
  end
end
