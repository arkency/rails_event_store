# frozen_string_literal: true

require 'aggregate_root'
require 'ruby_event_store'
require_relative '../../support/helpers/rspec_defaults'

module Orders
  module Events
    OrderCreated = Class.new(RubyEventStore::Event)
    OrderExpired = Class.new(RubyEventStore::Event)
    OrderCanceled = Class.new(RubyEventStore::Event)
    SpanishInquisition = Class.new(RubyEventStore::Event)
  end
end

class Order
  include AggregateRoot
  include Orders::Events

  def initialize(uuid)
    @status = :draft
    @uuid   = uuid
  end

  def create
    apply OrderCreated.new
  end

  def expire
    apply OrderExpired.new
  end

  attr_accessor :status

  private

  def apply_order_created(_event)
    @status = :created
  end

  def apply_order_expired(_event)
    @status = :expired
  end
end

class OrderWithNonStrictApplyStrategy
  include AggregateRoot.with_strategy(->{ AggregateRoot::DefaultApplyStrategy.new(strict: false) })
end

class CustomOrderApplyStrategy
  def call(aggregate, event)
    {
      'Orders::Events::OrderCreated' => aggregate.method(:custom_created),
      'Orders::Events::OrderExpired' => aggregate.method(:custom_expired),
    }.fetch(event.event_type, ->(ev) {}).call(event)
  end
end

class OrderWithCustomStrategy
  include AggregateRoot.with_strategy(-> { CustomOrderApplyStrategy.new })

  def initialize
    @status = :draft
  end

  attr_accessor :status

  private

  def custom_created(_event)
    @status = :created
  end

  def custom_expired(_event)
    @status = :expired
  end
end
