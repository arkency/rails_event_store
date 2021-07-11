# frozen_string_literal: true

module AggregateRoot
  MissingHandler = Class.new(StandardError)
  NullHandler    = Proc.new {}

  class DefaultApplyStrategy
    def initialize(strict: true)
      @strict = strict
    end

    def call(aggregate, event)
      on_handler(aggregate, event.event_type)[event]
    end

    private

    def on_handler(aggregate, event_type)
      on_method_name = aggregate.class.on_methods.fetch(event_type)
      aggregate.method(on_method_name)
    rescue KeyError
      missing_handler(aggregate, event_type)
    end

    def missing_handler(aggregate, event_type)
      if strict
        raise MissingHandler.new("Missing handler method on aggregate #{aggregate.class} for #{event_type}")
      else
        NullHandler
      end
    end

    attr_reader :strict
  end
end
