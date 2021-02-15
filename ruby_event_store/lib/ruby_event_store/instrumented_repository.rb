# frozen_string_literal: true

module RubyEventStore
  class InstrumentedRepository
    def initialize(repository, instrumentation)
      @repository = repository
      @instrumentation = instrumentation
    end

    def append_to_stream(records, stream, expected_version)
      instrumentation.instrument("append_to_stream.repository.rails_event_store", events: records, stream: stream) do
        repository.append_to_stream(records, stream, expected_version)
      end
    end

    def link_to_stream(event_ids, stream, expected_version)
      instrumentation.instrument("link_to_stream.repository.rails_event_store", event_ids: event_ids, stream: stream) do
        repository.link_to_stream(event_ids, stream, expected_version)
      end
    end

    def delete_stream(stream)
      instrumentation.instrument("delete_stream.repository.rails_event_store", stream: stream) do
        repository.delete_stream(stream)
      end
    end

    def has_event?(event_id)
      repository.has_event?(event_id)
    end

    def last_stream_event(stream)
      repository.last_stream_event(stream)
    end

    def read(specification)
      instrumentation.instrument("read.repository.rails_event_store", specification: specification) do
        repository.read(specification)
      end
    end

    def count(specification)
      instrumentation.instrument("count.repository.rails_event_store", specification: specification) do
        repository.count(specification)
      end
    end

    def update_messages(messages)
      instrumentation.instrument("update_messages.repository.rails_event_store", messages: messages) do
        repository.update_messages(messages)
      end
    end

    def streams_of(event_id)
      instrumentation.instrument("streams_of.repository.rails_event_store", event_id: event_id) do
        repository.streams_of(event_id)
      end
    end

    def inspect
      "#<#{self.class}:0x#{__id__.to_s(16)} inner_repository=#{repository.inspect}>"
    end

    private
    attr_reader :repository, :instrumentation
  end
end
