# frozen_string_literal: true

module AggregateRoot
  class Repository
    def initialize(event_store)
      @event_store = event_store
    end

    def load(aggregate, stream_name)
      event_store.read.stream(stream_name).reduce { |_, ev| aggregate.apply(ev) }
      aggregate.version = aggregate.unpublished_events.count - 1
      aggregate
    end

    def store(aggregate, stream_name)
      event_store.publish(aggregate.unpublished_events.to_a,
        stream_name:      stream_name,
        expected_version: aggregate.version)
      aggregate.version = aggregate.version + aggregate.unpublished_events.count
    end

    def with_aggregate(aggregate, stream_name, &block)
      block.call(load(aggregate, stream_name))
      store(aggregate, stream_name)
    end

    private

    attr_reader :event_store
  end
end
