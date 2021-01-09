require 'spec_helper'
require 'ruby_event_store'
require 'ruby_event_store/spec/event_repository_lint'

module RailsEventStoreActiveRecord
  class EventRepository
    class SpecHelper < RubyEventStore::EventRepositoryHelper
      def supports_concurrent_auto?
        !ENV['DATABASE_URL'].include?("sqlite")
      end

      def supports_concurrent_any?
        !ENV['DATABASE_URL'].include?("sqlite")
      end

      def has_connection_pooling?
        true
      end

      def connection_pool_size
        ActiveRecord::Base.connection.pool.size
      end

      def cleanup_concurrency_test
        ActiveRecord::Base.connection_pool.disconnect!
      end
    end
  end

  RSpec.describe EventRepository do
    include_examples :event_repository
    let(:repository) { EventRepository.new(serializer: YAML) }
    let(:helper) { EventRepository::SpecHelper.new }
    let(:time) { Time.now.utc }

    include SchemaHelper
    around(:each) do |example|
      begin
        establish_database_connection
        load_database_schema
        example.run
      ensure
        drop_database
      end
    end

    let(:specification) do
      RubyEventStore::Specification.new(
        RubyEventStore::SpecificationReader.new(
          repository,
          RubyEventStore::Mappers::Default.new
        )
      )
    end

    specify "does not confuse all with GLOBAL_STREAM" do
      repository.append_to_stream(
        [RubyEventStore::SRecord.new(event_id: "fbce0b3d-40e3-4d1d-90a1-901f1ded5a4a")],
        RubyEventStore::Stream.new('all'),
        RubyEventStore::ExpectedVersion.none
      )

      repository.append_to_stream(
        [RubyEventStore::SRecord.new(event_id: "a1b49edb-7636-416f-874a-88f94b859bef")],
        RubyEventStore::Stream.new(RubyEventStore::GLOBAL_STREAM),
        RubyEventStore::ExpectedVersion.any
      )
      expect(repository.read(specification.result))
        .to(contains_ids(%w[fbce0b3d-40e3-4d1d-90a1-901f1ded5a4a a1b49edb-7636-416f-874a-88f94b859bef]))

      expect(repository.read(specification.stream('all').result))
        .to(contains_ids(%w[fbce0b3d-40e3-4d1d-90a1-901f1ded5a4a]))
    end

    specify "using preload()" do
      repository.append_to_stream([
        event0 = RubyEventStore::SRecord.new,
        event1 = RubyEventStore::SRecord.new,
      ], RubyEventStore::Stream.new('stream'), RubyEventStore::ExpectedVersion.auto)
      c1 = count_queries{ repository.read(specification.limit(2).result) }
      expect(c1).to eq(1)

      c2 = count_queries{ repository.read(specification.limit(2).backward.result) }
      expect(c2).to eq(1)

      c3 = count_queries{ repository.read(specification.stream("stream").result) }
      expect(c3).to eq(2)

      c4 = count_queries{ repository.read(specification.stream("stream").backward.result) }
      expect(c4).to eq(2)

      c5 = count_queries{ repository.read(specification.stream("stream").limit(2).result) }
      expect(c5).to eq(2)

      c6 = count_queries{ repository.read(specification.stream("stream").limit(2).backward.result) }
      expect(c6).to eq(2)
    end

    specify "explicit sorting by position rather than accidental" do
      e1 = Event.create!(
        event_id: u1 = SecureRandom.uuid,
        data: '{}',
        metadata: '{}',
        event_type: "TestDomainEvent",
        valid_at: time,
      )
      e2 = Event.create!(
        event_id: u2 = SecureRandom.uuid,
        data: '{}',
        metadata: '{}',
        event_type: "TestDomainEvent",
        valid_at: time,
      )
      e3 = Event.create!(
        event_id: u3 = SecureRandom.uuid,
        data: '{}',
        metadata: '{}',
        event_type: "TestDomainEvent",
        valid_at: time,
      )
      EventInStream.create!(
        stream:   "stream",
        position: 1,
        event_id: e2.event_id,
      )
      EventInStream.create!(
        stream:   "stream",
        position: 0,
        event_id: e1.event_id,
      )
      EventInStream.create!(
        stream:   "stream",
        position: 2,
        event_id: e3.event_id,
      )
      ActiveRecord::Schema.define do
        self.verbose = false
        remove_index :event_store_events_in_streams, [:stream, :position]
      end

      expect(repository.read(specification.stream("stream").limit(3).result).map(&:event_id)).to eq([u1,u2,u3])
      expect(repository.read(specification.stream("stream").result).map(&:event_id)).to eq([u1,u2,u3])

      expect(repository.read(specification.stream("stream").backward.limit(3).result).map(&:event_id)).to eq([u3,u2,u1])
      expect(repository.read(specification.stream("stream").backward.result).map(&:event_id)).to eq([u3,u2,u1])
    end

    specify "explicit sorting by id rather than accidental for all events" do
      e1 = Event.create!(
        event_id: u1 = SecureRandom.uuid,
        data: '{}',
        metadata: '{}',
        event_type: "TestDomainEvent",
        valid_at: time,
      )
      e2 = Event.create!(
        event_id: u2 = SecureRandom.uuid,
        data: '{}',
        metadata: '{}',
        event_type: "TestDomainEvent",
        valid_at: time,
      )
      e3 = Event.create!(
        event_id: u3 = SecureRandom.uuid,
        data: '{}',
        metadata: '{}',
        event_type: "TestDomainEvent",
        valid_at: time,
      )
      EventInStream.create!(
        stream:   "all",
        position: 1,
        event_id: e1.event_id,
      )
      EventInStream.create!(
        stream:   "all",
        position: 0,
        event_id: e2.event_id,
      )
      EventInStream.create!(
        stream:   "all",
        position: 2,
        event_id: e3.event_id,
      )

      expect(repository.read(specification.limit(3).result).map(&:event_id)).to eq([u1,u2,u3])
      expect(repository.read(specification.limit(3).backward.result).map(&:event_id)).to eq([u3,u2,u1])
    end

    specify do
      e1 = Event.create!(
        event_id: u1 = SecureRandom.uuid,
        data: '{}',
        metadata: '{}',
        event_type: "TestDomainEvent",
        valid_at: time,
      )
      e2 = Event.create!(
        event_id: u2 = SecureRandom.uuid,
        data: '{}',
        metadata: '{}',
        event_type: "TestDomainEvent",
        valid_at: time,
      )
      e3 = Event.create!(
        event_id: u3 = SecureRandom.uuid,
        data: '{}',
        metadata: '{}',
        event_type: "TestDomainEvent",
        valid_at: time,
      )
      EventInStream.create!(
        stream:   "all",
        position: 1,
        event_id: e1.event_id,
      )
      EventInStream.create!(
        stream:   "all",
        position: 0,
        event_id: e2.event_id,
      )
      EventInStream.create!(
        stream:   "all",
        position: 2,
        event_id: e3.event_id,
      )

      expect(repository.read(specification.to(u3).limit(3).result).map(&:event_id)).to eq([u1,u2])
      expect(repository.read(specification.to(u1).limit(3).backward.result).map(&:event_id)).to eq([u3,u2])
    end

    specify do
      expect_query(/SELECT.*FROM.*event_store_events.*ORDER BY .*event_store_events.*id.* ASC LIMIT.*/) do
        repository.read(specification.limit(3).result)
      end
    end

    specify do
      expect_query(/SELECT.*FROM.*event_store_events.*ORDER BY .*event_store_events.*id.* DESC LIMIT.*/) do
        repository.read(specification.limit(3).backward.result)
      end
    end

    specify do
      expect_query(/SELECT.*FROM.*event_store_events_in_streams.*ORDER BY .*event_store_events_in_streams.*position.* ASC, .*event_store_events_in_streams.*id.* ASC LIMIT.*/) do
        repository.read(specification.stream('stream').limit(3).result)
      end
    end

    specify do
      expect_query(/SELECT.*FROM.*event_store_events_in_streams.*ORDER BY .*event_store_events_in_streams.*position.* DESC, .*event_store_events_in_streams.*id.* DESC LIMIT.*/) do
        repository.read(specification.stream('stream').limit(3).backward.result)
      end
    end

    specify "explicit ORDER BY position" do
      expect_query(/SELECT.*FROM.*event_store_events_in_streams.*WHERE.*event_store_events_in_streams.*stream.*=.*ORDER BY position DESC LIMIT.*/) do
        repository.append_to_stream([
          RubyEventStore::SRecord.new,
        ], RubyEventStore::Stream.new('stream'), RubyEventStore::ExpectedVersion.auto)
      end
    end

    specify "nested transaction - events still not persisted if append failed" do
      repository.append_to_stream([
        event = RubyEventStore::SRecord.new(event_id: SecureRandom.uuid),
      ], RubyEventStore::Stream.new('stream'), RubyEventStore::ExpectedVersion.none)

      ActiveRecord::Base.transaction do
        expect do
          repository.append_to_stream([
            RubyEventStore::SRecord.new(
              event_id: '9bedf448-e4d0-41a3-a8cd-f94aec7aa763'
            ),
          ], RubyEventStore::Stream.new('stream'), RubyEventStore::ExpectedVersion.none)
        end.to raise_error(RubyEventStore::WrongExpectedEventVersion)
        expect(repository.has_event?('9bedf448-e4d0-41a3-a8cd-f94aec7aa763')).to be_falsey
        expect(repository.read(specification.limit(2).result).to_a).to eq([event])
      end
      expect(repository.has_event?('9bedf448-e4d0-41a3-a8cd-f94aec7aa763')).to be_falsey
      expect(repository.read(specification.limit(2).result).to_a).to eq([event])
    end

    specify "limited query when looking for unexisting events during linking" do
      expect_query(/SELECT.*event_store_events.*id.*FROM.*event_store_events.*WHERE.*event_store_events.*id.*=.*/) do
        expect do
          repository.link_to_stream(['72922e65-1b32-4e97-8023-03ae81dd3a27'], RubyEventStore::Stream.new("flow"), RubyEventStore::ExpectedVersion.none)
        end.to raise_error(RubyEventStore::EventNotFound)
      end
    end

    specify 'read in batches forward' do
      events = Array.new(200) { RubyEventStore::SRecord.new }
      repository.append_to_stream(
        events,
        RubyEventStore::Stream.new(RubyEventStore::GLOBAL_STREAM),
        RubyEventStore::ExpectedVersion.any
      )

      batches = repository.read(specification.forward.limit(101).in_batches.result).to_a
      expect(batches.size).to eq(2)
      expect(batches[0].size).to eq(100)
      expect(batches[1].size).to eq(1)
      expect(batches[0]).to eq(events[0..99])
      expect(batches[1]).to eq([events[100]])
    end

    specify 'read in batches backward' do
      events = Array.new(200) { RubyEventStore::SRecord.new }
      repository.append_to_stream(
        events,
        RubyEventStore::Stream.new(RubyEventStore::GLOBAL_STREAM),
        RubyEventStore::ExpectedVersion.any
      )

      batches = repository.read(specification.backward.limit(101).in_batches.result).to_a
      expect(batches.size).to eq(2)
      expect(batches[0].size).to eq(100)
      expect(batches[1].size).to eq(1)
      expect(batches[0]).to eq(events[100..-1].reverse)
      expect(batches[1]).to eq([events[99]])
    end

    specify 'read in batches forward from named stream' do
      all_events = Array.new(400) { RubyEventStore::SRecord.new }
      all_events.each_slice(2) do |(first, second)|
        repository.append_to_stream(
          [first],
          RubyEventStore::Stream.new("bazinga"),
          RubyEventStore::ExpectedVersion.any
        )
        repository.append_to_stream(
          [second],
          RubyEventStore::Stream.new(RubyEventStore::GLOBAL_STREAM),
          RubyEventStore::ExpectedVersion.any
        )
      end
      stream_events = all_events.each_with_index.select { |event, idx| event if idx % 2 == 0 }.map { |event, idx| event }
      batches = repository.read(specification.stream("bazinga").forward.limit(101).in_batches.result).to_a
      expect(batches.size).to eq(2)
      expect(batches[0].size).to eq(100)
      expect(batches[1].size).to eq(1)
      expect(batches[0]).to eq(stream_events[0..99])
      expect(batches[1]).to eq([stream_events[100]])
    end

    specify 'use default models' do
      repository = EventRepository.new(serializer: YAML)
      expect(repository.instance_variable_get(:@event_klass)).to be(Event)
      expect(repository.instance_variable_get(:@stream_klass)).to be(EventInStream)
    end

    specify 'allows custom base class' do
      repository = EventRepository.new(model_factory: WithAbstractBaseClass.new(CustomApplicationRecord), serializer: YAML)
      expect(repository.instance_variable_get(:@event_klass).ancestors).to include(CustomApplicationRecord)
      expect(repository.instance_variable_get(:@stream_klass).ancestors).to include(CustomApplicationRecord)
    end

    specify 'reading/writting works with custom base class' do
      repository = EventRepository.new(model_factory: WithAbstractBaseClass.new(CustomApplicationRecord), serializer: YAML)
      repository.append_to_stream(
        [event = RubyEventStore::SRecord.new],
        RubyEventStore::Stream.new(RubyEventStore::GLOBAL_STREAM),
        RubyEventStore::ExpectedVersion.any
      )
      reader = RubyEventStore::SpecificationReader.new(repository, RubyEventStore::Mappers::Default.new)
      specification = RubyEventStore::Specification.new(reader)
      read_event = repository.read(specification.result).first
      expect(read_event).to eq(event)
    end

    specify 'timestamps not overwritten by activerecord-import' do
      repository.append_to_stream(
        [event = RubyEventStore::SRecord.new(timestamp: time = Time.at(0))],
        RubyEventStore::Stream.new(RubyEventStore::GLOBAL_STREAM),
        RubyEventStore::ExpectedVersion.any
      )
      event_ = repository.read(specification.result).first
      expect(event_.timestamp).to eq(time)
    end

    specify 'with post-valid-at appended record' do
      Event.create!(
        event_id: id = SecureRandom.uuid,
        data: '{}',
        metadata: '{}',
        event_type: "TestDomainEvent",
        created_at: t1 = with_precision(Time.now.utc),
        valid_at:   t2 = with_precision(Time.at(0)),
      )
      EventInStream.create!(
        stream:   "stream",
        position: 1,
        event_id: id,
        created_at: t1,
      )

      record = repository.read(specification.result).first
      expect(record.timestamp).to eq(t1)
      expect(record.valid_at).to  eq(t2)
    end

    specify 'with pre-valid-at appended record' do
      Event.create!(
        event_id: id = SecureRandom.uuid,
        data: '{}',
        metadata: '{}',
        event_type: "TestDomainEvent",
        created_at: t = with_precision(Time.now.utc),
        valid_at: nil,
      )
      EventInStream.create!(
        stream:   "stream",
        position: 1,
        event_id: id,
        created_at: t,
      )

      record = repository.read(specification.result).first
      expect(record.timestamp).to eq(t)
      expect(record.valid_at).to  eq(t)
    end

    specify 'valid-at storage optimization when same as created-at' do
      repository.append_to_stream(
        [RubyEventStore::SRecord.new(timestamp: time = with_precision(Time.at(0)))],
        RubyEventStore::Stream.new(RubyEventStore::GLOBAL_STREAM),
        RubyEventStore::ExpectedVersion.any
      )
      record = repository.read(specification.result).first
      expect(record.timestamp).to eq(time)
      expect(record.valid_at).to  eq(time)

      event_record = Event.find_by(event_id: record.event_id)
      expect(event_record.created_at).to eq(time)
      expect(event_record.valid_at).to   be_nil
    end

    specify 'no valid-at storage optimization when different from created-at' do
      repository.append_to_stream(
        [RubyEventStore::SRecord.new(
          timestamp: t1 = with_precision(Time.at(0)), 
          valid_at:  t2 = with_precision(Time.at(1))
        )],
        RubyEventStore::Stream.new(RubyEventStore::GLOBAL_STREAM),
        RubyEventStore::ExpectedVersion.any
      )
      record = repository.read(specification.result).first
      expect(record.timestamp).to eq(t1)
      expect(record.valid_at).to  eq(t2)

      event_record = Event.find_by(event_id: record.event_id)
      expect(event_record.created_at).to eq(t1)
      expect(event_record.valid_at).to   eq(t2)
    end

    def with_precision(time)
      time.round(RubyEventStore::TIMESTAMP_PRECISION)
    end

    def cleanup_concurrency_test
      ActiveRecord::Base.connection_pool.disconnect!
    end

    def verify_conncurency_assumptions
      expect(ActiveRecord::Base.connection.pool.size).to eq(5)
    end

    def additional_limited_concurrency_for_auto_check
      positions = RailsEventStoreActiveRecord::EventInStream
        .where(stream: "stream")
        .order("position ASC")
        .map(&:position)
      expect(positions).to eq((0..positions.size-1).to_a)
    end

    private

    def count_queries(&block)
      count = 0
      counter_f = ->(_name, _started, _finished, _unique_id, payload) {
        unless %w[ CACHE SCHEMA ].include?(payload[:name])
          count += 1
        end
      }
      ActiveSupport::Notifications.subscribed(counter_f, "sql.active_record", &block)
      count
    end

    def expect_query(match, &block)
      count = 0
      counter_f = ->(_name, _started, _finished, _unique_id, payload) {
        count +=1 if match === payload[:sql]
      }
      ActiveSupport::Notifications.subscribed(counter_f, "sql.active_record", &block)
      expect(count).to eq(1)
    end
  end
end
