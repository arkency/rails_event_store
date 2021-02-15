require 'spec_helper'

module RubyEventStore
  module Mappers
    module Transformation
      RSpec.describe EventClassRemapper do
        let(:time)  { Time.now.utc }
        let(:uuid)  { SecureRandom.uuid }
        def record(event_type: 'TestEvent')
          Record.new(
            event_id:   uuid,
            metadata:   {some: 'meta'},
            data:       {some: 'value'},
            event_type: event_type,
            timestamp:  time,
            valid_at:   time,
          )
        end
        let(:changeable_record) { record(event_type: 'EventNameBeforeRefactor') }
        let(:changed_record)    { record(event_type: 'SomethingHappened') }
        let(:class_map) { {'EventNameBeforeRefactor' => 'SomethingHappened'} }

        specify "#dump" do
          expect(EventClassRemapper.new(class_map).dump(record)).to eq(record)
          expect(EventClassRemapper.new(class_map).dump(record)).to eq(record)
        end

        specify "#load" do
          expect(EventClassRemapper.new(class_map).load(record)).to eq(record)
          expect(EventClassRemapper.new(class_map).load(changeable_record)).to eq(changed_record)
        end

        specify "#inspect" do
          transformation = EventClassRemapper.new(class_map)
          object_id = transformation.object_id.to_s(16)
          expect(transformation.inspect).to eq("#<RubyEventStore::Mappers::Transformation::EventClassRemapper:0x#{object_id}>")
        end
      end
    end
  end
end
