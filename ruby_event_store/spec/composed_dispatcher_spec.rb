require "spec_helper"
require 'ruby_event_store/spec/dispatcher_lint'

module RubyEventStore
  RSpec.describe ComposedDispatcher do
    skippy_dispatcher = Class.new do
      def call(_subscriber, _event, _record)
        @called = true
      end

      def verify(_subscriber)
        false
      end
      attr_reader :called
    end
    it_behaves_like :dispatcher, skippy_dispatcher.new

    real_dispatcher = Class.new do
      def call(_subscriber, _event, _record)
        @called = true
      end

      def verify(_subscriber)
        true
      end
      attr_reader :called
    end
    it_behaves_like :dispatcher, real_dispatcher.new

    it_behaves_like :dispatcher, ComposedDispatcher.new

    describe "#verify" do
      specify "pass subscriber to dispatcher" do
        dispatcher = spy
        composed_dispatcher = ComposedDispatcher.new(dispatcher)
        subscriber = double

        composed_dispatcher.verify(subscriber)

        expect(dispatcher).to have_received(:verify).with(subscriber)
      end

      specify "ok if at least one dispatcher truthy" do
        composed_dispatcher = ComposedDispatcher.new(skippy_dispatcher.new, real_dispatcher.new)

        subscriber = double
        expect(composed_dispatcher.verify(subscriber)).to eq(true)
      end

      specify "raise error if all dispatchers falsey" do
        composed_dispatcher = ComposedDispatcher.new(skippy_dispatcher.new)

        subscriber = double
        expect(composed_dispatcher.verify(subscriber)).to eq(false)
      end
    end

    describe "#call" do
      specify "pass arguments to dispatcher" do
        dispatcher = spy
        composed_dispatcher = ComposedDispatcher.new(dispatcher)
        event = instance_double(::RubyEventStore::Event)
        record = instance_double(::RubyEventStore::Record)
        subscriber = double

        composed_dispatcher.call(subscriber, event, record)

        expect(dispatcher).to have_received(:verify).with(subscriber)
        expect(dispatcher).to have_received(:call).with(subscriber, event, record)
      end

      specify "calls only verified dispatcher" do
        skippy = skippy_dispatcher.new
        real = real_dispatcher.new
        composed_dispatcher = ComposedDispatcher.new(skippy, real)
        event = instance_double(::RubyEventStore::Event)
        record = instance_double(::RubyEventStore::Record)
        subscriber = double

        composed_dispatcher.call(subscriber, event, record)

        expect(skippy.called).to be_falsey
        expect(real.called).to be_truthy
      end

      specify "calls only first verified dispatcher" do
        real1 = real_dispatcher.new
        real2 = real_dispatcher.new
        composed_dispatcher = ComposedDispatcher.new(real1, real2)
        event = instance_double(::RubyEventStore::Event)
        record = instance_double(::RubyEventStore::Record)
        subscriber = double

        composed_dispatcher.call(subscriber, event, record)

        expect(real1.called).to be_truthy
        expect(real2.called).to be_falsey
      end
    end

    specify "#inspect" do
      dispatcher1 = spy
      dispatcher2 = real_dispatcher.new
      composed_dispatcher = ComposedDispatcher.new(dispatcher1, dispatcher2)
      object_id = composed_dispatcher.object_id.to_s(16)
      expect(composed_dispatcher.inspect).to eq("#<RubyEventStore::ComposedDispatcher:0x#{object_id} dispatchers=[#{dispatcher1.inspect}, #{dispatcher2.inspect}]>")
    end
  end
end
