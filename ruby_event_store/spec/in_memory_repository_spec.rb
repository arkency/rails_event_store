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

      expect(repository.read(Specification.new(SpecificationReader.new(repository, Mappers::Default.new)).result))
        .to(contains_ids(%w[fbce0b3d-40e3-4d1d-90a1-901f1ded5a4a a1b49edb-7636-416f-874a-88f94b859bef]))

      expect(repository.read(Specification.new(SpecificationReader.new(repository, Mappers::Default.new)).stream('all').result))
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
  end
end
