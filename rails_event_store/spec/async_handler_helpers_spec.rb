require 'spec_helper'
require 'action_controller/railtie'
require_relative '../../support/helpers/silence_stdout'


SilenceStdout.silence_stdout { require 'sidekiq/testing' }

module RailsEventStore
  class HandlerWithDefaults < ActiveJob::Base
    cattr_accessor :event

    def perform(event)
      self.class.event = event
    end
  end

  class HandlerWithAnotherEventStore < ActiveJob::Base
    cattr_accessor :event

    def perform(event)
      self.class.event = event
    end
  end

  class HandlerWithSpecifiedSerializer < ActiveJob::Base
    cattr_accessor :event

    def perform(event)
      self.class.event = event
    end
  end

  class MyLovelyAsyncHandler < ActiveJob::Base
    cattr_accessor :event

    def perform(payload)
      self.class.event = Rails.configuration.event_store.deserialize(serializer: YAML, **payload)
    end
  end

  class SidekiqHandlerWithHelper
    include Sidekiq::Worker

    cattr_accessor :event

    def perform(event)
      self.class.event = event
    end
  end

  class HandlerWithHelper < ActiveJob::Base
    cattr_accessor :event

    def perform(event)
      self.class.event = event
    end
  end

  class MetadataHandler < ActiveJob::Base
    cattr_accessor :metadata

    def perform(_event)
      self.metadata = Rails.configuration.event_store.metadata
    end
  end

  class CustomSidekiqScheduler
    def call(klass, record)
      klass.perform_async(record.serialize(YAML).to_h)
    end

    def verify(subscriber)
      Class === subscriber && subscriber.respond_to?(:perform_async)
    end
  end

  RSpec.describe AsyncHandler do
    let(:event_store) { RailsEventStore::Client.new }
    let(:another_event_store) { RailsEventStore::Client.new }
    let(:json_event_store) {
      RailsEventStore::Client.new(
        dispatcher: RubyEventStore::ImmediateAsyncDispatcher.new(
          scheduler: ActiveJobScheduler.new(serializer: JSON)
        ),
      )
    }
    let(:application) { instance_double(Rails::Application) }
    let(:config)      { FakeConfiguration.new }

    before do
      allow(Rails).to       receive(:application).and_return(application)
      allow(application).to receive(:config).and_return(config)
      Rails.configuration.event_store = event_store
      ActiveJob::Base.queue_adapter   = :async
    end

    specify "with defaults" do
      HandlerWithDefaults.prepend RailsEventStore::AsyncHandler
      handler = HandlerWithDefaults.new

      HandlerWithDefaults.event = nil
      event_store.subscribe_to_all_events(HandlerWithDefaults)
      event_store.publish(ev = RubyEventStore::Event.new)
      wait_until{ HandlerWithDefaults.event }
      expect(HandlerWithDefaults.event).to eq(ev)
    end

    specify "with specified event store" do
      HandlerWithAnotherEventStore.prepend RailsEventStore::AsyncHandler.with(event_store: another_event_store)
      handler = HandlerWithAnotherEventStore.new

      HandlerWithAnotherEventStore.event = nil
      event_store.subscribe_to_all_events(HandlerWithAnotherEventStore)
      event_store.publish(ev = RubyEventStore::Event.new)
      wait_until{ HandlerWithAnotherEventStore.event }
      expect(HandlerWithAnotherEventStore.event).to eq(ev)
    end

    specify "with specified serializer" do
      HandlerWithSpecifiedSerializer.prepend RailsEventStore::AsyncHandler.with(event_store: json_event_store, serializer: JSON)
      handler = HandlerWithSpecifiedSerializer.new

      HandlerWithSpecifiedSerializer.event = nil
      json_event_store.subscribe_to_all_events(HandlerWithSpecifiedSerializer)
      json_event_store.publish(ev = RubyEventStore::Event.new)
      wait_until{ HandlerWithSpecifiedSerializer.event }
      expect(HandlerWithSpecifiedSerializer.event).to eq(ev)
    end

    specify 'default dispatcher can into ActiveJob' do
      MyLovelyAsyncHandler.event = nil
      event_store.subscribe_to_all_events(MyLovelyAsyncHandler)
      event_store.publish(ev = RubyEventStore::Event.new)
      wait_until{ MyLovelyAsyncHandler.event }
      expect(MyLovelyAsyncHandler.event).to eq(ev)
    end

    specify 'ActiveJob with AsyncHandler prepended' do
      HandlerWithHelper.prepend RailsEventStore::AsyncHandler
      HandlerWithHelper.event = nil
      event_store.subscribe_to_all_events(HandlerWithHelper)
      event_store.publish(ev = RubyEventStore::Event.new)
      wait_until{ HandlerWithHelper.event }
      expect(HandlerWithHelper.event).to eq(ev)
    end

    specify 'ActiveJob with CorrelatedHandler prepended' do
      HandlerA = Class.new(MetadataHandler)
      HandlerA.prepend RailsEventStore::CorrelatedHandler
      HandlerA.prepend RailsEventStore::AsyncHandler
      HandlerA.metadata = nil
      event_store.subscribe_to_all_events(HandlerA)
      event_store.publish(ev = RubyEventStore::Event.new)
      wait_until{ HandlerA.metadata }
      expect(HandlerA.metadata).to eq({
        correlation_id: ev.correlation_id,
        causation_id:   ev.event_id,
      })
    end

    specify 'ActiveJob with CorrelatedHandler prepended (2)' do
      HandlerB = Class.new(MetadataHandler)
      HandlerB.prepend RailsEventStore::CorrelatedHandler
      HandlerB.prepend RailsEventStore::AsyncHandler
      HandlerB.metadata = nil
      event_store.subscribe_to_all_events(HandlerB)
      event_store.publish(ev = RubyEventStore::Event.new(
        metadata: {
          correlation_id: "COID",
          causation_id:   "CAID",
        }
      ))
      wait_until{ HandlerB.metadata }
      expect(HandlerB.metadata).to eq({
        correlation_id: "COID",
        causation_id:   ev.event_id,
      })
    end

    specify 'ActiveJob with sidekiq adapter that requires serialization', mutant: false do
      ActiveJob::Base.queue_adapter = :sidekiq
      ev = RubyEventStore::Event.new
      Sidekiq::Testing.fake! do
        MyLovelyAsyncHandler.event = nil
        event_store.subscribe_to_all_events(MyLovelyAsyncHandler)
        event_store.publish(ev)
        Thread.new{ Sidekiq::Worker.drain_all }.join
      end
      expect(MyLovelyAsyncHandler.event).to eq(ev)
    end

    specify 'Sidekiq::Worker without ActiveJob that requires serialization' do
      event_store = RailsEventStore::Client.new(
        dispatcher: RubyEventStore::ImmediateAsyncDispatcher.new(scheduler: CustomSidekiqScheduler.new)
      )
      ev = RubyEventStore::Event.new
      Sidekiq::Testing.fake! do
        SidekiqHandlerWithHelper.prepend RailsEventStore::AsyncHandler.with(serializer: YAML)
        SidekiqHandlerWithHelper.event = nil
        event_store.subscribe_to_all_events(SidekiqHandlerWithHelper)
        event_store.publish(ev)
        Thread.new{ Sidekiq::Worker.drain_all }.join
      end
      expect(SidekiqHandlerWithHelper.event).to eq(ev)
    end

    specify 'CorrelatedHandler with event not yet scheduled with correlation_id' do
      HandlerB = Class.new(MetadataHandler)
      HandlerB.prepend RailsEventStore::CorrelatedHandler
      HandlerB.prepend RailsEventStore::AsyncHandler
      HandlerB.metadata = nil
      event_store.append(ev = RubyEventStore::Event.new)
      ev = event_store.read.event(ev.event_id)
      HandlerB.perform_now(serialize_without_correlation_id(ev))
      expect(HandlerB.metadata).to eq({
        correlation_id: nil,
        causation_id:   ev.event_id,
      })
    end

    private

    def serialize_without_correlation_id(ev)
      serialized =
        event_store
        .__send__(:mapper)
        .event_to_record(ev)
        .serialize(YAML)
        .to_h
      serialized[:metadata] = "--- {}\n"
      serialized
    end

    def wait_until(&block)
      Timeout.timeout(1) do
        loop do
          break if block.call
          sleep(0.001)
        end
      end
    end
  end
end
