require 'spec_helper'

class Aggregate_1
  include AggregateRoot

  def publish_event_1
    apply(Event_1.new(data: {}))
  end

  def do_something_in_reaction_to_event_2
  end

  def apply_event_1(event)
  end
end

class Aggregate_2
  include AggregateRoot

  def publish_event_2
    apply(Event_2.new(data: {}))
  end

  def apply_event_2(event)
  end
end

class Event_1 < RubyEventStore::Event
end

class Event_2 < RubyEventStore::Event
end

module AggregateRoot
  RSpec.describe "Issue #290" do
    specify do
      event_store = RubyEventStore::Client.new(
        repository: RubyEventStore::InMemoryRepository.new,
      )
      aggregate_repository = AggregateRoot::Repository.new(event_store)
      aggregate_1 = aggregate_repository.load(Aggregate_1.new, "stream_1")

      event_store.subscribe(
        -> _ {
          aggregate_repository = AggregateRoot::Repository.new(event_store)
          aggregate_2 = aggregate_repository.load(Aggregate_2.new, "stream_2")
          aggregate_2.publish_event_2
          aggregate_repository.store(aggregate_2, "stream_2")
        },
        to: [Event_1]
      )

      event_store.subscribe(
        -> _ {
          # uncommenting the code should fix the bug
          # aggregate_1.instance_variable_set(:@version, (aggregate_1.instance_variable_get(:@version) || -1) + aggregate_1.unpublished_events.size)
          # aggregate_1.instance_variable_set(:@unpublished_events, [])
          aggregate_1.do_something_in_reaction_to_event_2
          expect do
            aggregate_repository.store(aggregate_1, "stream_1")
          end.not_to raise_error
        },
        to: [Event_2]
      )
      aggregate_1.publish_event_1

      aggregate_repository.store(aggregate_1, "stream_1")
    end
  end
end
