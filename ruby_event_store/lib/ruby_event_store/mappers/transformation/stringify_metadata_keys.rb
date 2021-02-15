# frozen_string_literal: true

module RubyEventStore
  module Mappers
    module Transformation
      class StringifyMetadataKeys
        def dump(record)
          stringify(record)
        end

        def load(record)
          stringify(record)
        end

        def inspect
          "#<#{self.class}:0x#{__id__.to_s(16)}>"
        end

        private
        def stringify(record)
          Record.new(
            event_id:   record.event_id,
            event_type: record.event_type,
            data:       record.data,
            metadata:   TransformKeys.stringify(record.metadata),
            timestamp:  record.timestamp,
            valid_at:   record.valid_at,
          )
        end
      end
    end
  end
end
