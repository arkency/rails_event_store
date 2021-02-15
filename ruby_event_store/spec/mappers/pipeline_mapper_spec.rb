require 'spec_helper'
require 'ruby_event_store/spec/mapper_lint'

module RubyEventStore
  module Mappers
    RSpec.describe PipelineMapper do
      specify "#inspect" do
        to_domain_event = Transformation::DomainEvent.new
        to_serialized_record = Transformation::SerializedRecord.new
        symbolize_metadata_keys = Transformation::SymbolizeMetadataKeys.new
        mapper = PipelineMapper.new(Pipeline.new(
          to_domain_event: to_domain_event,
          to_serialized_record: to_serialized_record,
          transformations: [symbolize_metadata_keys]
        ))
        object_id = mapper.object_id.to_s(16)
        expect(mapper.inspect).to eq("#<RubyEventStore::Mappers::PipelineMapper:0x#{object_id} transformations=[#{to_domain_event.inspect}, #{symbolize_metadata_keys.inspect}, #{to_serialized_record.inspect}]>")
      end
    end
  end
end
