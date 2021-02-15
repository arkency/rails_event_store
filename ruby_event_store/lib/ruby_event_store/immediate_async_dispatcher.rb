# frozen_string_literal: true

module RubyEventStore
  class ImmediateAsyncDispatcher
    def initialize(scheduler:)
      @scheduler = scheduler
    end

    def call(subscriber, _, record)
      @scheduler.call(subscriber, record)
    end

    def verify(subscriber)
      @scheduler.verify(subscriber)
    end

    def inspect
      "#<#{self.class}:0x#{__id__.to_s(16)} scheduler=#{@scheduler.inspect}>"
    end
  end
end
