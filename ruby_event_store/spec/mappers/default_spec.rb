require 'spec_helper'
require 'json'
require 'ruby_event_store/spec/mapper_lint'

SomethingHappened = Class.new(RubyEventStore::Event)

module RubyEventStore
  module Mappers
    RSpec.describe Default do
      let(:time)         { Time.now.utc }
      let(:data)         { {some_attribute: 5} }
      let(:metadata)     { {some_meta: 1} }
      let(:event_id)     { SecureRandom.uuid }
      let(:domain_event) { TimeEnrichment.with(SomethingHappened.new(data: data, metadata: metadata, event_id: event_id), timestamp: time, valid_at: time) }

      it_behaves_like :mapper, Default.new, TimeEnrichment.with(SomethingHappened.new)

      specify '#event_to_record returns transformed record' do
        record = subject.event_to_record(domain_event)
        expect(record).to            be_a Record
        expect(record.event_id).to   eq event_id
        expect(record.data).to       eq({ some_attribute: 5 })
        expect(record.metadata).to   eq({ some_meta: 1 })
        expect(record.event_type).to eq "SomethingHappened"
        expect(record.timestamp).to  eq(time)
        expect(record.valid_at).to   eq(time)
      end

      specify '#record_to_event returns event instance' do
        record = Record.new(
          event_id:   domain_event.event_id,
          data:       { some_attribute: 5 },
          metadata:   { some_meta: 1},
          event_type: SomethingHappened.name,
          timestamp:  time,
          valid_at:   time,
        )
        event = subject.record_to_event(record)
        expect(event).to               eq(domain_event)
        expect(event.event_id).to      eq domain_event.event_id
        expect(event.data).to          eq(data)
        expect(event.metadata.to_h).to eq(metadata.merge(timestamp: time, valid_at: time))
        expect(event.metadata[:timestamp]).to eq(time)
        expect(event.metadata[:valid_at]).to  eq(time)
      end

      specify 'metadata keys are symbolized' do
        record = Record.new(
          event_id:   domain_event.event_id,
          data:       { some_attribute: 5 },
          metadata:   stringify({ some_meta: 1}),
          event_type: SomethingHappened.name,
          timestamp:  time,
          valid_at:   time,
        )
        event = subject.record_to_event(record)
        expect(event).to               eq(domain_event)
        expect(event.event_id).to      eq domain_event.event_id
        expect(event.data).to          eq(data)
        expect(event.metadata.to_h).to eq(metadata.merge(timestamp: time, valid_at: time))
        expect(event.metadata[:timestamp]).to eq(time)
        expect(event.metadata[:valid_at]).to  eq(time)
      end

      private

      def stringify(hash)
        hash.each_with_object({}) do |(k, v), memo|
          memo[k.to_s] = v
        end
      end
    end
  end
end
