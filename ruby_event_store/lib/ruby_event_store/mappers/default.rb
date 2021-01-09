# frozen_string_literal: true

module RubyEventStore
  module Mappers
    class Default < PipelineMapper
      def initialize
        super(Pipeline.new(
          Transformation::SymbolizeMetadataKeys.new,
        ))
      end
    end
  end
end
