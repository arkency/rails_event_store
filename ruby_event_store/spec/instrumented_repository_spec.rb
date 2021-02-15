require 'spec_helper'
require 'ruby_event_store/spec/event_repository_lint'
require 'active_support/core_ext/object/try'
require 'active_support/notifications'

module RubyEventStore
  RSpec.describe InstrumentedRepository do
    let(:record)           { SRecord.new }
    let(:stream)           { Stream.new("SomeStream") }
    let(:expected_version) { ExpectedVersion.any }
    let(:event_id)         { SecureRandom.uuid }

    describe "#append_to_stream" do
      specify "wraps around original implementation" do
        some_repository = spy
        instrumented_repository = InstrumentedRepository.new(some_repository, ActiveSupport::Notifications)
        instrumented_repository.append_to_stream([record], stream, expected_version)

        expect(some_repository).to have_received(:append_to_stream).with([record], stream, expected_version)
      end

      specify "instruments" do
        instrumented_repository = InstrumentedRepository.new(spy, ActiveSupport::Notifications)
        subscribe_to("append_to_stream.repository.rails_event_store") do |notification_calls|
          instrumented_repository.append_to_stream([record], stream, expected_version)

          expect(notification_calls).to eq([
            { events: [record], stream: stream }
          ])
        end
      end
    end

    describe "#link_to_stream" do
      specify "wraps around original implementation" do
        some_repository = spy
        instrumented_repository = InstrumentedRepository.new(some_repository, ActiveSupport::Notifications)
        instrumented_repository.link_to_stream([event_id], stream, expected_version)

        expect(some_repository).to have_received(:link_to_stream).with([event_id], stream, expected_version)
      end

      specify "instruments" do
        instrumented_repository = InstrumentedRepository.new(spy, ActiveSupport::Notifications)
        subscribe_to("link_to_stream.repository.rails_event_store") do |notification_calls|
          instrumented_repository.link_to_stream([event_id], stream, expected_version)

          expect(notification_calls).to eq([
            { event_ids: [event_id], stream: stream }
          ])
        end
      end
    end

    describe "#delete_stream" do
      specify "wraps around original implementation" do
        some_repository = spy
        instrumented_repository = InstrumentedRepository.new(some_repository, ActiveSupport::Notifications)
        instrumented_repository.delete_stream("SomeStream")

        expect(some_repository).to have_received(:delete_stream).with("SomeStream")
      end

      specify "instruments" do
        instrumented_repository = InstrumentedRepository.new(spy, ActiveSupport::Notifications)
        subscribe_to("delete_stream.repository.rails_event_store") do |notification_calls|
          instrumented_repository.delete_stream("SomeStream")

          expect(notification_calls).to eq([
            { stream: "SomeStream" }
          ])
        end
      end
    end

    describe "#has_event?" do
      specify "wraps around original implementation" do
        some_repository = spy
        instrumented_repository = InstrumentedRepository.new(some_repository, ActiveSupport::Notifications)
        instrumented_repository.has_event?(event_id)

        expect(some_repository).to have_received(:has_event?).with(event_id)
      end
    end

    describe "#last_stream_event" do
      specify "wraps around original implementation" do
        some_repository = spy
        instrumented_repository = InstrumentedRepository.new(some_repository, ActiveSupport::Notifications)
        instrumented_repository.last_stream_event("SomeStream")

        expect(some_repository).to have_received(:last_stream_event).with("SomeStream")
      end
    end

    describe "#read" do
      specify "wraps around original implementation" do
        some_repository = spy
        instrumented_repository = InstrumentedRepository.new(some_repository, ActiveSupport::Notifications)
        specification = double
        instrumented_repository.read(specification)

        expect(some_repository).to have_received(:read).with(specification)
      end

      specify "instruments" do
        instrumented_repository = InstrumentedRepository.new(spy, ActiveSupport::Notifications)
        subscribe_to("read.repository.rails_event_store") do |notification_calls|
          specification = double
          instrumented_repository.read(specification)

          expect(notification_calls).to eq([
            { specification: specification }
          ])
        end
      end
    end

    describe "#count" do
      specify "wraps around original implementation" do
        some_repository = spy
        instrumented_repository = InstrumentedRepository.new(some_repository, ActiveSupport::Notifications)
        specification = double
        instrumented_repository.count(specification)

        expect(some_repository).to have_received(:count).with(specification)
      end

      specify "instruments" do
        instrumented_repository = InstrumentedRepository.new(spy, ActiveSupport::Notifications)
        subscribe_to("count.repository.rails_event_store") do |notification_calls|
          specification = double
          instrumented_repository.count(specification)

          expect(notification_calls).to eq([
            { specification: specification }
          ])
        end
      end
    end

    describe "#update_messages" do
      specify "wraps around original implementation" do
        some_repository = spy
        instrumented_repository = InstrumentedRepository.new(some_repository, ActiveSupport::Notifications)
        instrumented_repository.update_messages([record])

        expect(some_repository).to have_received(:update_messages).with([record])
      end

      specify "instruments" do
        instrumented_repository = InstrumentedRepository.new(spy, ActiveSupport::Notifications)
        subscribe_to("update_messages.repository.rails_event_store") do |notification_calls|
          instrumented_repository.update_messages([record])

          expect(notification_calls).to eq([
            { messages: [record] }
          ])
        end
      end
    end

    describe "#streams_of" do
      specify "wraps around original implementation" do
        some_repository = spy
        instrumented_repository = InstrumentedRepository.new(some_repository, ActiveSupport::Notifications)
        uuid = SecureRandom.uuid
        instrumented_repository.streams_of(uuid)

        expect(some_repository).to have_received(:streams_of).with(uuid)
      end

      specify "instruments" do
        instrumented_repository = InstrumentedRepository.new(spy, ActiveSupport::Notifications)
        subscribe_to("streams_of.repository.rails_event_store") do |notification_calls|
          uuid = SecureRandom.uuid
          instrumented_repository.streams_of(uuid)

          expect(notification_calls).to eq([
            { event_id: uuid }
          ])
        end
      end
    end

    def subscribe_to(name)
      received_payloads = []
      callback = ->(_name, _start, _finish, _id, payload) { received_payloads << payload }
      ActiveSupport::Notifications.subscribed(callback, name) do
        yield received_payloads
      end
    end
  end
end

module RubyEventStore
  class InstrumentedRepository
    class SpecHelper < EventRepositoryHelper
      def supports_concurrent_auto?
        false
      end

      def supports_concurrent_any?
        false
      end

      def supports_binary?
        false
      end

      def supports_upsert?
        false
      end
    end
  end

  RSpec.describe InstrumentedRepository do
    include_examples :event_repository
    let(:repository) { InstrumentedRepository.new(InMemoryRepository.new, ActiveSupport::Notifications) }
    let(:helper) { InstrumentedRepository::SpecHelper.new }

    specify "#inspect" do
      in_memory_repository = InMemoryRepository.new
      instrumented_repository = InstrumentedRepository.new(in_memory_repository, ActiveSupport::Notifications)
      instrumented_repository_id = instrumented_repository.object_id.to_s(16)
      expect(instrumented_repository.inspect).to eq("#<RubyEventStore::InstrumentedRepository:0x#{instrumented_repository_id} inner_repository=#{in_memory_repository.inspect}>")
    end
  end
end
