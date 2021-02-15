require 'spec_helper'
require 'json'

module RubyEventStore
  module Mappers
    module Transformation
      RSpec.describe SymbolizeMetadataKeys do
        let(:time)  { Time.now.utc }
        let(:uuid)  { SecureRandom.uuid }
        let(:record)  {
          Record.new(
            event_id:   uuid,
            metadata:   {some: 'meta'},
            data:       JSON.parse(JSON.dump({some: 'value'})),
            event_type: 'TestEvent',
            timestamp:  time,
            valid_at:   time
          )
        }
        let(:changed_record)  {
          Record.new(
            event_id:   uuid,
            metadata:   JSON.parse(JSON.dump({some: 'meta'})),
            data:       JSON.parse(JSON.dump({some: 'value'})),
            event_type: 'TestEvent',
            timestamp:  time,
            valid_at:   time
          )
        }

        specify "#dump" do
          result = SymbolizeMetadataKeys.new.dump(changed_record)
          expect(result).to eq(record)
          expect(result.metadata.keys.map(&:class).uniq).to eq([Symbol])
        end

        specify "#load" do
          result = SymbolizeMetadataKeys.new.load(changed_record)
          expect(result).to eq(record)
          expect(result.metadata.keys.map(&:class).uniq).to eq([Symbol])
        end

        specify "#inspect" do
          transformation = SymbolizeMetadataKeys.new
          object_id = transformation.object_id.to_s(16)
          expect(transformation.inspect).to eq("#<RubyEventStore::Mappers::Transformation::SymbolizeMetadataKeys:0x#{object_id}>")
        end
      end
    end
  end
end
