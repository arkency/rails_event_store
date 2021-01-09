---
title: Custom Repository
---

## Installation with Bundler

By default RailsEventStore will use the ActiveRecord event repository. If you want to use another event repository without loading unnecessary ActiveRecord dependency, you'll need to do:

```ruby
gem 'rails_event_store', require: 'rails_event_store/all'
gem 'your_custom_repository'
```

After running `bundle install`, Rails Event Store should be ready to be used.
See custom repository README to learn how to setup its data store.

## Configure custom repository

```ruby
Rails.application.configure do
  config.to_prepare do
    Rails.configuration.event_store = RailsEventStore::Client.new(
      repository: YourCustomRepository.new
    )
  end
end
```

## Community event repositories

Those repositories were written by community members and are not guaranteed to be up to date with latest Rails event store.

- [rails_event_store_mongoid](https://github.com/gottfrois/rails_event_store_mongoid) by [Pierre-Louis Gottfrois](https://github.com/gottfrois)

## Writing your own repository

If you want to write your own repository, we provide [a suite of tests that you can re-use](https://github.com/RailsEventStore/rails_event_store/blob/master/ruby_event_store/lib/ruby_event_store/spec/event_repository_lint.rb). Just [require](https://github.com/RailsEventStore/rails_event_store/blob/a6ffb8a535373023296222bbbb5dd6ee131a6792/rails_event_store_active_record/spec/event_repository_spec.rb#L3) and [include it](https://github.com/RailsEventStore/rails_event_store/blob/a6ffb8a535373023296222bbbb5dd6ee131a6792/rails_event_store_active_record/spec/event_repository_spec.rb#L26) in your repository spec. Make sure to meditate on which [expected_version option](/docs/v1/expected_version//) you are going to support and how.

# Using RubyEventStore::InMemoryRepository for faster tests

RubyEventStore comes with `RubyEventStore::InMemoryRepository` that you can use in tests instead of the default one. `InMemoryRepository` does not persist events but offers the same characteristics as `RailsEventStoreActiveRecord::EventRepository`. It is tested with the same test suite and raises identical exceptions.

```ruby
RSpec.configure do |c|
  c.around(:each)
    Rails.configuration.event_store = RailsEventStore::Client.new(
      repository: RubyEventStore::InMemoryRepository.new
    )
    # add subscribers here
  end
end
```

If you want even faster tests you can additionally skip event's serialization.

```ruby
RSpec.configure do |c|
  c.around(:each)
    Rails.configuration.event_store = RailsEventStore::Client.new(
      repository: RubyEventStore::InMemoryRepository.new,
    )
    # add subscribers here
  end
end
```

We don't recommend using `InMemoryRepository` in production even if you don't need to persist events because the repository keeps all published events in memory. This is acceptable in testing because you can throw the instance away for every test and garbage collector reclaims the memory. In production, your memory would keep growing until you restart the application server.

# Using Ruby Object Mapper (ROM) for SQL without ActiveRecord or Rails

RubyEventStore comes with `RubyEventStore::ROM::EventRepository` that you can use with a SQL database without requiring ActiveRecord or when not using Rails altogether. It is tested with the same test suite as the ActiveRecord implementation and raises identical exceptions.

See [Using Ruby Event Store without Rails](https://railseventstore.org/docs/v1/without_rails//) for information on how to use ROM (and Sequel).

# Using PgLinearizedEventRepository for linearized writes

`rails_event_store_active_record` comes with additional version of repository named `RailsEventStoreActiveRecord::PgLinearizedEventRepository`.
It is almost the same as regular active record repository, but has linearized writes to the database and is only restricted to work in `PostgreSQL` database (as the name suggests).

There are usecases, where you may want to use event store as a queue. For example, you may want to build some read models on separate server and in order to build them correctly, you need to process the facts in the order they were written. In general case it is not that easy, because SQL databases auto-increment rows in the moment of insertion, not commit. So that allows event numbered 42 be already committed, but event numbered 40 still be somewhere in transaction, not readable from outside world. Therefore, the easiest implementation of such queue: "Remember the last processed event id" would not work in that case.

There are many subtleties in this topic, but one of the simplest solutions is to linearize all writes to event store. That's what `RailsEventStoreActiveRecord::PgLinearizedEventRepository` is for. Of course by linearizing your writes you lose performance and you make it impossible to scale your application above certain level. As usually, your mileage may vary, but such solution is undoubtedly the simplest and _good enough_ in some usecases.
