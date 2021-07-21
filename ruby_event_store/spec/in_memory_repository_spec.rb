require 'spec_helper'
require 'ruby_event_store/spec/event_repository_lint'


module RubyEventStore
  RSpec.describe InMemoryRepository do
    include_examples :event_repository
    let(:repository) { InMemoryRepository.new }
    let(:helper) { EventRepositoryHelper.new }

    it 'does not confuse all with GLOBAL_STREAM' do
      repository.append_to_stream(
        [SRecord.new(event_id: "fbce0b3d-40e3-4d1d-90a1-901f1ded5a4a")],
        Stream.new('all'),
        ExpectedVersion.none
      )
      repository.append_to_stream(
        [SRecord.new(event_id: "a1b49edb-7636-416f-874a-88f94b859bef")],
        Stream.new('stream'),
        ExpectedVersion.none
      )

      expect(repository.read(Specification.new(SpecificationReader.new(repository, Mappers::NullMapper.new)).result))
        .to(contains_ids(%w[fbce0b3d-40e3-4d1d-90a1-901f1ded5a4a a1b49edb-7636-416f-874a-88f94b859bef]))

      expect(repository.read(Specification.new(SpecificationReader.new(repository, Mappers::NullMapper.new)).stream('all').result))
        .to(contains_ids(%w[fbce0b3d-40e3-4d1d-90a1-901f1ded5a4a]))
    end

    it 'does not allow same event twice in a stream - checks stream events before checking all events' do
      repository.append_to_stream(
        [SRecord.new(event_id: eid = "fbce0b3d-40e3-4d1d-90a1-901f1ded5a4a")],
        Stream.new('other'),
        ExpectedVersion.none
      )
      repository.append_to_stream(
        [SRecord.new(event_id: "a1b49edb-7636-416f-874a-88f94b859bef")],
        Stream.new('stream'),
        ExpectedVersion.none
      )
      expect(eid).not_to receive(:eql?)
      expect do
        repository.append_to_stream(
          [SRecord.new(event_id: "a1b49edb-7636-416f-874a-88f94b859bef")],
          Stream.new('stream'),
          ExpectedVersion.new(0)
        )
      end.to raise_error(RubyEventStore::EventDuplicatedInStream)
    end

    it 'global position starts at 1' do
      repository.append_to_stream(
        [SRecord.new(event_id: eid = "fbce0b3d-40e3-4d1d-90a1-901f1ded5a4a")],
        Stream.new('other'),
        ExpectedVersion.none
      )

      expect(repository.global_position(eid)).to eq(1)
    end

    it 'global position increments by 1' do
      repository.append_to_stream(
        [
          SRecord.new(event_id: eid1 = "fbce0b3d-40e3-4d1d-90a1-901f1ded5a4a"),
          SRecord.new(event_id: eid2 = "0b81c542-7fef-47a1-9d81-f45915d74e9b"),
        ],
        Stream.new('other'),
        ExpectedVersion.none
      )

      expect(repository.global_position(eid2)).to eq(2)
    end

    it 'publishing with any position to stream with specific position raise an error' do
      repository.append_to_stream([
        event0 = SRecord.new,
      ], stream, version_auto)

      expect do
        repository.append_to_stream([
          event1 = SRecord.new,
        ], stream, version_any)
      end.to raise_error(RubyEventStore::InMemoryRepository::UnsupportedVersionAnyUsage)
    end

    it 'publishing with specific position to stream with any position raise an error' do
      repository.append_to_stream([
        event0 = SRecord.new,
      ], stream, version_any)

      expect do
        repository.append_to_stream([
          event1 = SRecord.new,
        ], stream, version_auto)
      end.to raise_error(RubyEventStore::InMemoryRepository::UnsupportedVersionAnyUsage)
    end
  end
end
