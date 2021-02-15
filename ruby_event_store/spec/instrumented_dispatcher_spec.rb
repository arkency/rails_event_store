require 'spec_helper'
require 'ruby_event_store/spec/dispatcher_lint'
require 'active_support/core_ext/object/try'
require 'active_support/notifications'

module RubyEventStore
  RSpec.describe InstrumentedDispatcher do
    it_behaves_like :dispatcher, InstrumentedDispatcher.new(Dispatcher.new, ActiveSupport::Notifications)

    describe "#call" do
      specify "wraps around original implementation" do
        some_dispatcher = spy
        instrumented_dispatcher = InstrumentedDispatcher.new(some_dispatcher, ActiveSupport::Notifications)
        event = Object.new
        record = Object.new
        subscriber = -> { }

        instrumented_dispatcher.call(subscriber, event, record)

        expect(some_dispatcher).to have_received(:call).with(subscriber, event, record)
      end

      specify "instruments" do
        instrumented_dispatcher = InstrumentedDispatcher.new(spy, ActiveSupport::Notifications)
        subscribe_to("call.dispatcher.rails_event_store") do |notification_calls|
          event = Object.new
          record = Object.new
          subscriber = -> { }

          instrumented_dispatcher.call(subscriber, event, record)

          expect(notification_calls).to eq([
            { event: event, subscriber: subscriber }
          ])
        end
      end
    end

    describe "#verify" do
      specify "wraps around original implementation" do
        some_dispatcher = spy
        instrumented_dispatcher = InstrumentedDispatcher.new(some_dispatcher, ActiveSupport::Notifications)
        subscriber = -> { }

        instrumented_dispatcher.verify(subscriber)

        expect(some_dispatcher).to have_received(:verify).with(subscriber)
      end
    end

    specify "#inspect" do
      some_dispatcher = spy
      dispatcher = InstrumentedDispatcher.new(some_dispatcher, ActiveSupport::Notifications)
      object_id = dispatcher.object_id.to_s(16)
      expect(dispatcher.inspect).to eq("#<RubyEventStore::InstrumentedDispatcher:0x#{object_id} dispatcher=#{some_dispatcher.inspect}>")
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
