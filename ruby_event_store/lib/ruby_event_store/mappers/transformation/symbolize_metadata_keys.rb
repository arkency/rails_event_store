# frozen_string_literal: true

module RubyEventStore
  module Mappers
    module Transformation
      class SymbolizeMetadataKeys
        def dump(record)
          symbolize(record)
        end

        def load(record)
          symbolize(record)
        end

        def inspect
          "#<#{self.class}:0x#{__id__.to_s(16)}>"
        end

        private
        def symbolize(record)
          Record.new(
            event_id:   record.event_id,
            event_type: record.event_type,
            data:       record.data,
            metadata:   TransformKeys.symbolize(record.metadata),
            timestamp:  record.timestamp,
            valid_at:   record.valid_at,
          )
        end
      end
    end
  end
end
