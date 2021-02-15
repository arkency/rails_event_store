# frozen_string_literal: true

require 'active_support/core_ext/array'
require 'activerecord-import'

module RailsEventStoreActiveRecord
  class EventRepository
    POSITION_SHIFT = 1

    def initialize(model_factory: WithDefaultModels.new, serializer:)
      @serializer  = serializer

      @event_klass, @stream_klass = model_factory.call
      @repo_reader = EventRepositoryReader.new(@event_klass, @stream_klass, serializer)
      @index_violation_detector = IndexViolationDetector.new(@event_klass.table_name, @stream_klass.table_name)
    end

    def append_to_stream(records, stream, expected_version)
      hashes    = []
      event_ids = []
      records.each do |record|
        hashes    << import_hash(record, record.serialize(serializer))
        event_ids << record.event_id
      end
      add_to_stream(event_ids, stream, expected_version) do
        @event_klass.import(hashes)
      end
    end

    def link_to_stream(event_ids, stream, expected_version)
      (event_ids - @event_klass.where(event_id: event_ids).pluck(:event_id)).each do |id|
        raise RubyEventStore::EventNotFound.new(id)
      end
      add_to_stream(event_ids, stream, expected_version)
    end

    def delete_stream(stream)
      @stream_klass.where(stream: stream.name).delete_all
    end

    def has_event?(event_id)
      @repo_reader.has_event?(event_id)
    end

    def last_stream_event(stream)
      @repo_reader.last_stream_event(stream)
    end

    def read(specification)
      @repo_reader.read(specification)
    end

    def count(specification)
      @repo_reader.count(specification)
    end

    def update_messages(records)
      hashes  = records.map { |record| import_hash(record, record.serialize(serializer)) }
      for_update = records.map(&:event_id)
      start_transaction do
        existing = @event_klass.where(event_id: for_update).pluck(:event_id, :id).to_h
        (for_update - existing.keys).each{|id| raise RubyEventStore::EventNotFound.new(id) }
        hashes.each { |h| h[:id] = existing.fetch(h.fetch(:event_id)) }
        @event_klass.import(hashes, on_duplicate_key_update: [:data, :metadata, :event_type, :valid_at])
      end
    end

    def streams_of(event_id)
      @stream_klass.where(event_id: event_id)
        .pluck(:stream)
        .map { |name| RubyEventStore::Stream.new(name) }
    end

    def inspect
      "#<#{self.class}:0x#{__id__.to_s(16)}>"
    end

    private
    attr_reader :serializer

    def add_to_stream(event_ids, stream, expected_version)
      last_stream_version = ->(stream_) { @stream_klass.where(stream: stream_.name).order("position DESC").first.try(:position) }
      resolved_version = expected_version.resolve_for(stream, last_stream_version)

      start_transaction do
        yield if block_given?
        in_stream = event_ids.map.with_index do |event_id, index|
          {
            stream:   stream.name,
            position: compute_position(resolved_version, index),
            event_id: event_id,
          }
        end
        @stream_klass.import(in_stream) unless stream.global?
      end
      self
    rescue ActiveRecord::RecordNotUnique => e
      raise_error(e)
    end

    def raise_error(e)
      if detect_index_violated(e.message)
        raise RubyEventStore::EventDuplicatedInStream
      end
      raise RubyEventStore::WrongExpectedEventVersion
    end

    def compute_position(resolved_version, index)
      unless resolved_version.nil?
        resolved_version + index + POSITION_SHIFT
      end
    end

    def detect_index_violated(message)
      @index_violation_detector.detect(message)
    end

    def import_hash(record, serialized_record)
      {
        event_id:   serialized_record.event_id,
        data:       serialized_record.data,
        metadata:   serialized_record.metadata,
        event_type: serialized_record.event_type,
        created_at: record.timestamp,
        valid_at:   optimize_timestamp(record.valid_at, record.timestamp),
      }
    end

    def optimize_timestamp(valid_at, created_at)
      valid_at unless valid_at.eql?(created_at)
    end

    def start_transaction(&block)
      @event_klass.transaction(requires_new: true, &block)
    end
  end

end
