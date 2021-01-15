---
title: Instrumentation
---

RailsEventStore ships with built-in instrumentation. You can build your own features, improve logging or implement tracing on top of it. It can also be the way to integrate with 3rd party services for like NewRelic RPM, Skylight or AppSignal.

## Enabling instrumentation

### RubyEventStore

The `ruby_event_store` gem is not integrated with any particular instrumenter implementation. We don't enforce this dependency. Only require such instrumenter to have the same API as `ActiveSupport::Notifications`. One can for example use standalone [as-notifications](https://github.com/bernd/as-notifications) gem.

Instrumentation is provided by repository, mapper and dispatcher decorators:

* `RubyEventStore::InstrumentedRepository`
* `RubyEventStore::Mappers::InstrumentedMapper`
* `RubyEventStore::InstrumentedDispatcher`

In order to enable it, wrap the components you intend to instrument with corresponding decorators and instrumenter of your choice:

```ruby
instrumenter = ActiveSupport::Notifications

RubyEventStore::Client.new(
  repository: RubyEventStore::InstrumentedRepository.new(
    RubyEventStore::InMemoryRepository.new, instrumenter
  ),
  mapper: RubyEventStore::Mappers::InstrumentedMapper.new(
    RubyEventStore::Mappers::Default.new, instrumenter
  ),
  dispatcher: RubyEventStore::InstrumentedDispatcher.new(
    RubyEventStore::Dispatcher.new, instrumenter
  )
)
```

You can also instrument your own repository, mapper or dispatcher components the same way.


### AggregateRoot

The `aggregate_root` gem is not integrated with any particular instrumenter implementation — same as with `ruby_event_store`.

Instrumentation is provided by `AggregateRoot::InstrumentedReposiory` decorator. In order to enable instrumentation, wrap the aggregate root repository with its instrumented decorator and the instrumenter of your choice:

```ruby
instrumenter = ActiveSupport::Notifications
repository   = AggregateRoot::InstrumentedRepository.new(
  AggregateRoot::Repository.new(event_store),
  instrumenter
)
```


### RailsEventStore

The `rails_event_store` gem is integrated with `ActiveSupport::Notifications` that ships with Rails. By default `RailsEventStore::Client` instance ships with already instrumented repository, mapper and a dispatcher. 

You can start [subscribing](https://guides.rubyonrails.org/active_support_instrumentation.html#subscribing-to-an-event) to the instrumentation hooks by now:

```ruby
hook_name = "append_to_stream.repository.ruby_event_store"

ActiveSupport::Notifications.subscribe(hook_name) do |name, start, finish, id, payload|
  metric = ActiveSupport::Notifications::Event.new(name, start, finish, id, payload)
  NewRelic::Agent.record_metric('Custom/RES/append_to_stream', metric.duration)
end
```

The aggregate root repository instrumentation is not enabled automaticly here. The event store is a dependency passed to aggregate root repository and has no control over it. You have to decorate this repository yourself.

## Hooks and their payloads

#### append_to_stream.repository.ruby_event_store

| Key     | Value |
| ------- | ----- |
| :records | An array of appended [RubyEventStore::Record](https://www.rubydoc.info/gems/ruby_event_store/RubyEventStore/Record) objects |
| :stream | A [RubyEventStore::Stream](https://www.rubydoc.info/gems/ruby_event_store/RubyEventStore/Stream) that we append events to |

```ruby
{
  records: [#<RubyEventStore::Record:0x0000000104b51f30>],
  stream: #<RubyEventStore::Stream:0x0000000106cbf578>
}
```


#### link_to_stream.repository.ruby_event_store

| Key        | Value |
| ---------- | ----- |
| :event_ids | An array of linked event identifiers |
| :stream    | A [RubyEventStore::Stream](https://www.rubydoc.info/gems/ruby_event_store/RubyEventStore/Stream) that we link events to |

```ruby
{
  event_ids: ["71c38b38-4c72-4f95-86e2-203898f98c8e",
   "82dcf1eb-ec4e-48c6-b061-de7ce03fb6af"],
  stream: #<RubyEventStore::Stream:0x0000000106cbf578>
}
```


#### delete_stream.repository.ruby_event_store

| Key     | Value |
| ------- | ----- |
| :stream | A [RubyEventStore::Stream](https://www.rubydoc.info/gems/ruby_event_store/RubyEventStore/Stream) that we delete |

```ruby
{
  stream: #<RubyEventStore::Stream:0x0000000106cbf578>
}
```


#### read.repository.ruby_event_store

| Key            | Value |
| -------------- | ----- |
| :specification | A [RubyEventStore::SpecificationResult](https://www.rubydoc.info/gems/ruby_event_store/RubyEventStore/SpecificationResult) describing the query requested from event store |

```ruby
{
  specification: #<RubyEventStore::SpecificationResult:0x0000000113644d80>
}
```


#### count.repository.ruby_event_store

| Key            | Value |
| -------------- | ----- |
| :specification | A [RubyEventStore::SpecificationResult](https://www.rubydoc.info/gems/ruby_event_store/RubyEventStore/SpecificationResult) describing the query requested from event store |

```ruby
{
  specification: #<RubyEventStore::SpecificationResult:0x0000000113644d80>
}
```


#### update_messages.repository.ruby_event_store

| Key            | Value |
| -------------- | ----- |
| :records      | An array of [RubyEventStore::Record](https://www.rubydoc.info/gems/ruby_event_store/RubyEventStore/Record) objects to replace existing ones of the same identifiers |

```ruby
{
  records: [#<RubyEventStore::Record:0x0000000109e4ff98]
}
```


#### streams_of.repository.ruby_event_store

| Key            | Value |
| -------------- | ----- |
| :event_id      | An identifier of the event used to query for streams it is present in |

```ruby
{
  event_id: "8cee1139-4f96-483a-a175-2b947283c3c7"
}
```


#### call.dispatcher.ruby_event_store

| Key         | Value |
| ----------- | ----- |
| :event      | An event instance which is being dispatched           |
| :subscriber | A subscriber to which event is dispatched to |

```ruby
{
  event: #<MyEvent:0x000000010e786658>,
  subscriber: #<Proc:0x00000001123ecb10>
}
```


#### event_to_record.mapper.ruby_event_store

| Key         | Value |
| ----------- | ----- |
| :event | An event instance which is being mapped into RubyEventStore::Record |

```ruby
{
  domain_event: #<MyEvent:0x000000010e786658>
}
```

#### record_to_event.mapper.ruby_event_store

| Key         | Value |
| ----------- | ----- |
| :record | An instance of [RubyEventStore::Record](https://www.rubydoc.info/gems/ruby_event_store/RubyEventStore/Record) which is being mapped into an event |

```ruby
{
  record: #<RubyEventStore::Record:0x0000000104b51f30>
}
```


#### load.repository.aggregate_root

| Key         | Value |
| ----------- | ----- |
| :aggregate  | An instance of an aggregate on which loaded events are being applied |
| :stream     | A stream name to load events from |

```ruby
{
  aggregate: #<Order:0x00000001141f97c0>,
  stream: "Order$42"
}
```


#### store.repository.aggregate_root

| Key         | Value |
| ----------- | ----- |
| :aggregate  | An instance of an aggregate whose events are being stored |
| :stream     | A stream name to which events are stored |
| :version     | An [expected version](https://railseventstore.org/docs/v2/expected_version/#explicit-number-integer-from-1) of the stream to which events are stored |
| :stored_events | An array of events that are stored as a result of actions performed on this aggregate |


```ruby
{
  aggregate: #<Order:0x00000001141f97c0>,
  stream: "Order$42",
  version: -1,
  stored_events: [
    #<Orders::Events::OrderCreated:0x000000011428a950>,
    #<Orders::Events::OrderExpired:0x000000011428a2c0>
  ]
}
```