# frozen_string_literal: true

module RubyEventStore
  class InstrumentedDispatcher
    def initialize(dispatcher, instrumentation)
      @dispatcher = dispatcher
      @instrumentation = instrumentation
    end

    def call(subscriber, event, record)
      instrumentation.instrument("call.dispatcher.rails_event_store", event: event, subscriber: subscriber) do
        dispatcher.call(subscriber, event, record)
      end
    end

    def verify(subscriber)
      dispatcher.verify(subscriber)
    end

    def inspect
      "#<#{self.class}:0x#{__id__.to_s(16)} dispatcher=#{@dispatcher.inspect}>"
    end

    private
    attr_reader :instrumentation, :dispatcher
  end
end
