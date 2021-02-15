require 'spec_helper'
require 'ruby_event_store/spec/dispatcher_lint'

module RubyEventStore
  RSpec.describe Dispatcher do
    it_behaves_like :dispatcher, Dispatcher.new
    let(:event) { instance_double(::RubyEventStore::Event) }
    let(:record) { instance_double(::RubyEventStore::Record)  }
    let(:handler) { HandlerClass.new }

    specify "does not allow silly subscribers" do
      expect(Dispatcher.new.verify(:symbol)).to eq(false)
      expect(Dispatcher.new.verify(Object.new)).to eq(false)
    end

    specify "does not allow class without instance method #call" do
      klass = Class.new
      expect(Dispatcher.new.verify(klass)).to eq(false)
    end

    specify "does not allow class without constructor requiring arguments" do
      klass = Class.new do
        def initialize(something)
          @something = something
        end

        def call
        end
      end
      expect(Dispatcher.new.verify(klass)).to eq(false)
    end

    specify "calls subscribed instance" do
      expect(handler).to receive(:call).with(event)
      Dispatcher.new.call(handler, event, record)
    end

    specify "calls subscribed class" do
      expect(HandlerClass).to receive(:new).and_return(handler)
      expect(handler).to receive(:call).with(event)
      Dispatcher.new.call(HandlerClass, event, record)
    end

    specify "allows callable classes and instances" do
      expect(Dispatcher.new.verify(HandlerClass)).to eq(true)
      expect(Dispatcher.new.verify(HandlerClass.new)).to eq(true)
      expect(Dispatcher.new.verify(Proc.new{ "yo" })).to eq(true)
    end

    specify "#inspect" do
      dispatcher = Dispatcher.new
      object_id = dispatcher.object_id.to_s(16)
      expect(dispatcher.inspect).to eq("#<RubyEventStore::PubSub::Dispatcher:0x#{object_id}>")
    end

    private

    class HandlerClass
      @@received = nil
      def self.received
        @@received
      end
      def call(event)
        @@received = event
      end
    end
  end
end
