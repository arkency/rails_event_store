# frozen_string_literal: true

require 'ostruct'
module RubyEventStore
  class InMemoryRepository
    UnsupportedVersionAnyUsage = Class.new(StandardError)

    class EventInStream
      def initialize(event_id, position)
        @event_id = event_id
        @position = position
      end

      attr_reader :event_id, :position
    end

    class EventRecord
      def initialize(global_position, record)
        @global_position = global_position
        @record = record
      end

      attr_reader :global_position
      attr_accessor :record
    end

    def initialize(serializer: NULL)
      @serializer = serializer
      @streams = Hash.new { |h, k| h[k] = Array.new }
      @mutex   = Mutex.new
      @storage = Hash.new
      @next_global_position = 1
    end

    def append_to_stream(records, stream, expected_version)
      serialized_records = records.map { |record| record.serialize(serializer) }

      with_synchronize(expected_version, stream) do |resolved_version|
        raise UnsupportedVersionAnyUsage if resolved_version.nil? && !streams.fetch(stream.name, Array.new).map(&:position).compact.empty?
        raise WrongExpectedEventVersion unless resolved_version.nil? || last_stream_version(stream).equal?(resolved_version)

        serialized_records.each_with_index do |serialized_record, index|
          raise EventDuplicatedInStream if has_event?(serialized_record.event_id)
          storage[serialized_record.event_id] = EventRecord.new(next_global_position, serialized_record)
          @next_global_position += 1
          add_to_stream(stream, serialized_record, resolved_version, index)
        end
      end
      self
    end

    def link_to_stream(event_ids, stream, expected_version)
      serialized_records = event_ids.map { |id| read_event(id) }

      with_synchronize(expected_version, stream) do |resolved_version|
        raise WrongExpectedEventVersion unless resolved_version.nil? || last_stream_version(stream).equal?(resolved_version)

        serialized_records.each_with_index do |serialized_record, index|
          raise EventDuplicatedInStream if has_event_in_stream?(serialized_record.event_id, stream.name)
          add_to_stream(stream, serialized_record, resolved_version, index)
        end
      end
      self
    end

    def delete_stream(stream)
      streams.delete(stream.name)
    end

    def has_event?(event_id)
      storage.has_key?(event_id)
    end

    def last_stream_event(stream)
      last_id = event_ids_of_stream(stream).last
      storage.fetch(last_id).record.deserialize(serializer) if last_id
    end

    def read(spec)
      serialized_records = read_scope(spec)
      if spec.batched?
        batch_reader = ->(offset, limit) do
          serialized_records
            .drop(offset)
            .take(limit)
            .map { |serialized_record| serialized_record.deserialize(serializer) }
        end
        BatchEnumerator.new(spec.batch_size, serialized_records.size, batch_reader).each
      elsif spec.first?
        serialized_records.first&.deserialize(serializer)
      elsif spec.last?
        serialized_records.last&.deserialize(serializer)
      else
        Enumerator.new do |y|
          serialized_records.each do |serialized_record|
            y << serialized_record.deserialize(serializer)
          end
        end
      end
    end

    def count(spec)
      read_scope(spec).count
    end

    def update_messages(records)
      records.each do |record|
        read_event(record.event_id)
        serialized_record =
          Record.new(
            event_id:   record.event_id,
            event_type: record.event_type,
            data:       record.data,
            metadata:   record.metadata,
            timestamp:  Time.iso8601(storage.fetch(record.event_id).record.timestamp),
            valid_at:   record.valid_at,
          ).serialize(serializer)
        storage.fetch(record.event_id).record = serialized_record
      end
    end

    def streams_of(event_id)
      streams
        .select { |name,| has_event_in_stream?(event_id, name) }
        .map    { |name,| Stream.new(name) }
    end

    def position_in_stream(event_id, stream)
      event_in_stream = streams[stream.name].find {|event_in_stream| event_in_stream.event_id.eql?(event_id) }
      raise EventNotFoundInStream if event_in_stream.nil?
      event_in_stream.position
    end

    def global_position(event_id)
      storage.fetch(event_id) { raise EventNotFound.new(event_id) }.global_position
    end

    private
    def read_scope(spec)
      serialized_records = serialized_records_of_stream(spec.stream)
      serialized_records = ordered(serialized_records, spec)
      serialized_records = serialized_records.select{|e| spec.with_ids.any?{|x| x.eql?(e.event_id)}} if spec.with_ids?
      serialized_records = serialized_records.select{|e| spec.with_types.any?{|x| x.eql?(e.event_type)}} if spec.with_types?
      serialized_records = serialized_records.reverse if spec.backward?
      serialized_records = serialized_records.drop(index_of(serialized_records, spec.start) + 1) if spec.start
      serialized_records = serialized_records.take(index_of(serialized_records, spec.stop)) if spec.stop
      serialized_records = serialized_records.take(spec.limit) if spec.limit?
      serialized_records = serialized_records.select { |sr| Time.iso8601(sr.timestamp) < spec.older_than } if spec.older_than
      serialized_records = serialized_records.select { |sr| Time.iso8601(sr.timestamp) <= spec.older_than_or_equal } if spec.older_than_or_equal
      serialized_records = serialized_records.select { |sr| Time.iso8601(sr.timestamp) > spec.newer_than } if spec.newer_than
      serialized_records = serialized_records.select { |sr| Time.iso8601(sr.timestamp) >= spec.newer_than_or_equal } if spec.newer_than_or_equal
      serialized_records
    end

    def read_event(event_id)
      storage.fetch(event_id) { raise EventNotFound.new(event_id) }.record
    end

    def event_ids_of_stream(stream)
      streams.fetch(stream.name, Array.new).map(&:event_id)
    end

    def serialized_records_of_stream(stream)
      (stream.global? ? storage.values : storage.fetch_values(*event_ids_of_stream(stream))).map(&:record)
    end

    def ordered(serialized_records, spec)
      case spec.time_sort_by
      when :as_at
        serialized_records.sort_by(&:timestamp)
      when :as_of
        serialized_records.sort_by(&:valid_at)
      else
        serialized_records
      end
    end

    def last_stream_version(stream)
      events_in_stream = streams.fetch(stream.name, Array.new)
      if events_in_stream.empty?
        ExpectedVersion::POSITION_DEFAULT
      else
        events_in_stream.last.position
      end
    end

    def with_synchronize(expected_version, stream, &block)
      resolved_version = expected_version.resolve_for(stream, method(:last_stream_version))

      # expected_version :auto assumes external lock is used
      # which makes reading stream before writing safe.
      #
      # To emulate potential concurrency issues of :auto strategy without
      # such external lock we use Thread.pass to make race
      # conditions more likely. And we only use mutex.synchronize for writing
      # not for the whole read+write algorithm.
      Thread.pass
      mutex.synchronize do
        block.call(resolved_version)
      end
    end

    def has_event_in_stream?(event_id, stream_name)
      streams.fetch(stream_name, Array.new).any? { |event_in_stream| event_in_stream.event_id.eql?(event_id) }
    end

    def index_of(source, event_id)
      source.index {|item| item.event_id.eql?(event_id)}
    end

    def compute_position(resolved_version, index)
      unless resolved_version.nil?
        resolved_version + index + 1
      end
    end

    def add_to_stream(stream, serialized_record, resolved_version, index)
      streams[stream.name] << EventInStream.new(serialized_record.event_id, compute_position(resolved_version, index))
    end

    attr_reader :streams, :mutex, :storage, :serializer, :next_global_position
  end
end
