require 'spec_helper'
require 'json'

module RubyEventStore
  module Mappers
    module Transformation
      RSpec.describe StringifyMetadataKeys do
        let(:time)  { Time.now.utc }
        let(:uuid)  { SecureRandom.uuid }
        let(:record)  {
          Record.new(
            event_id:   uuid,
            metadata:   JSON.parse(JSON.dump({some: 'meta'})),
            data:       JSON.parse(JSON.dump({some: 'value'})),
            event_type: 'TestEvent',
            timestamp:  time,
            valid_at:   time
          )
        }
        let(:changed_record)  {
          Record.new(
            event_id:   uuid,
            metadata:   {some: 'meta'},
            data:       JSON.parse(JSON.dump({some: 'value'})),
            event_type: 'TestEvent',
            timestamp:  time,
            valid_at:   time
          )
        }

        specify "#dump" do
          result = StringifyMetadataKeys.new.dump(changed_record)
          expect(result).to eq(record)
          expect(result.metadata.keys.map(&:class).uniq).to eq([String])
        end

        specify "#load" do
          result = StringifyMetadataKeys.new.load(changed_record)
          expect(result).to eq(record)
          expect(result.metadata.keys.map(&:class).uniq).to eq([String])
        end

        specify "#inspect" do
          transformation = StringifyMetadataKeys.new
          object_id = transformation.object_id.to_s(16)
          expect(transformation.inspect).to eq("#<RubyEventStore::Mappers::Transformation::StringifyMetadataKeys:0x#{object_id}>")
        end
      end
    end
  end
end
