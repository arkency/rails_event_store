---
title: Instrumentation
---

RubyEventStore and RailsEventStore ships with built-in instrumentation on which you can build additional features or benchmark event store performance in your app.

## Enabling instrumentation

#### RailsEventStore

RailsEventStore is integrated with `ActiveSupport::Notifications` by default. You don't have to do anything else.

#### RubyEventStore

Instrumentation is provided by `InstrumentedRepository` and `InstrumentedDispatcher` decorators. We don't force any particular instrumentation framework, [as long as it has the same API](https://github.com/bernd/as-notifications) as `ActiveSupport::Notifications`.

That having said, if you want to instrument your event store with `ActiveSupport::Notifications`, initialize your client with following repository and/or dispatcher:

```ruby
repository = RailsEventStoreActiveRecord::EventRepository.new # or other repo you use
dispatcher = RubyEventStore::Dispatcher.new # or other dispatcher you use
RubyEventStore::Client.new(
  repository: InstrumentedRepository.new(repository, ActiveSupport::Notifications),
  dispatcher: InstrumentedDispatcher.new(dispatcher, ActiveSupport::Notifications)
)
```

## Usage

Subscribe to the hooks as [Rails guides](https://guides.rubyonrails.org/active_support_instrumentation.html#subscribing-to-an-event) and [manual](https://api.rubyonrails.org/classes/ActiveSupport/Notifications.html) recommend.

#### Example

```ruby
name = "append_to_stream.repository.ruby_event_store"
ActiveSupport::Notifications.subscribe(name) do |name, start, finish, id, payload|
  metric = ActiveSupport::Notifications::Event.new(name, start, finish, id, payload)
  NewRelic::Agent.record_metric('Custom/RES/append_to_stream', metric.duration)
end
```

## Hooks and their payloads

### `append_to_stream.repository.ruby_event_store`

| Key     | Value                              |
| ------- | ---------------------------------- |
| :events | Array of appended events           |
| :stream | Name of stream we append events to |

### `link_to_stream.repository.ruby_event_store`

| Key        | Value                            |
| ---------- | -------------------------------- |
| :event_ids | Array of linked events' ids      |
| :stream    | Name of stream we link events to |

### `delete_stream.repository.ruby_event_store`

| Key     | Value                  |
| ------- | ---------------------- |
| :stream | Name of stream deleted |

### `read_event.repository.ruby_event_store`

| Key       | Value                |
| --------- | -------------------- |
| :event_id | Id of the read event |

### `read.repository.ruby_event_store`

| Key            | Value                                     |
| -------------- | ----------------------------------------- |
| :specification | Specification of the query to event store |

Queries specification is not documented, but you can read the [source code of it](https://github.com/RailsEventStore/rails_event_store/blob/master/ruby_event_store/lib/ruby_event_store/specification.rb).

### `call.dispatcher.ruby_event_store`

| Key         | Value                                        |
| ----------- | -------------------------------------------- |
| :event      | An event which is being dispatched           |
| :subscriber | A subscriber to which event is dispatched to |
