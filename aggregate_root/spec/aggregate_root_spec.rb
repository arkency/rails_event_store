# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AggregateRoot do
  let(:event_store) { RubyEventStore::Client.new(repository: RubyEventStore::InMemoryRepository.new) }
  let(:uuid)        { SecureRandom.uuid }

  it "should have ability to apply event on itself" do
    order = Order.new(uuid)
    order_created = Orders::Events::OrderCreated.new

    expect(order).to receive(:"apply_order_created").with(order_created).and_call_original
    order.apply(order_created)
    expect(order.status).to eq :created
    expect(order.unpublished_events.to_a).to eq([order_created])
  end

  it "brand new aggregate does not have any unpublished events" do
    order = Order.new(uuid)
    expect(order.unpublished_events.to_a).to be_empty
  end

  it "should receive a method call based on a default apply strategy" do
    order = Order.new(uuid)
    order_created = Orders::Events::OrderCreated.new

    order.apply(order_created)
    expect(order.status).to eq :created
  end

  it "should raise error for missing apply method based on a default apply strategy" do
    order = Order.new(uuid)
    spanish_inquisition = Orders::Events::SpanishInquisition.new
    expect { order.apply(spanish_inquisition) }.to raise_error(AggregateRoot::MissingHandler, "Missing handler method apply_spanish_inquisition on aggregate Order")
  end

  it "should ignore missing apply method based on a default non-strict apply strategy" do
    order = OrderWithNonStrictApplyStrategy.new
    spanish_inquisition = Orders::Events::SpanishInquisition.new
    expect { order.apply(spanish_inquisition) }.to_not raise_error
  end

  it "should receive a method call based on a custom strategy" do
    order = OrderWithCustomStrategy.new
    order_created = Orders::Events::OrderCreated.new

    order.apply(order_created)
    expect(order.status).to eq :created
  end

  it "should return applied events" do
    order = Order.new(uuid)
    created = Orders::Events::OrderCreated.new
    expired = Orders::Events::OrderExpired.new

    applied = order.apply(created, expired)
    expect(applied).to eq([created, expired])
  end

  it "should return only applied events" do
    order = Order.new(uuid)
    created = Orders::Events::OrderCreated.new
    order.apply(created)

    expired = Orders::Events::OrderExpired.new
    applied = order.apply(expired)
    expect(applied).to eq([expired])
  end

  it "#unpublished_events method is public" do
    order = Order.new(uuid)
    expect(order.unpublished_events.to_a).to eq([])

    created = Orders::Events::OrderCreated.new
    order.apply(created)
    expect(order.unpublished_events.to_a).to eq([created])

    expired = Orders::Events::OrderExpired.new
    order.apply(expired)
    expect(order.unpublished_events.to_a).to eq([created, expired])
  end

  it "#unpublished_events method does not allow modifying internal state directly" do
    order = Order.new(uuid)
    expect(order.unpublished_events.respond_to?(:<<)).to eq(false)
    expect(order.unpublished_events.respond_to?(:clear)).to eq(false)
    expect(order.unpublished_events.respond_to?(:push)).to eq(false)
    expect(order.unpublished_events.respond_to?(:shift)).to eq(false)
    expect(order.unpublished_events.respond_to?(:pop)).to eq(false)
    expect(order.unpublished_events.respond_to?(:unshift)).to eq(false)
  end

  describe ".on" do
    it "generates private apply handler method" do
      order_with_ons = Class.new do
        include AggregateRoot

        on Orders::Events::OrderCreated do |_ev|
          @status = :created
        end

        on 'Orders::Events::OrderExpired' do |_ev|
          @status = :expired
        end

        attr_accessor :status
      end

      inherited_order_with_ons = Class.new(order_with_ons) do
        on Orders::Events::OrderCreated do |_ev|
          @status = :created_inherited
        end

        on Orders::Events::OrderCanceled do |_ev|
          @status = :canceled_inherited
        end
      end

      order = order_with_ons.new
      order.apply(Orders::Events::OrderCreated.new)
      expect(order.status).to eq(:created)
      order.apply(Orders::Events::OrderExpired.new)
      expect(order.status).to eq(:expired)

      expect(order.private_methods).to include(:"on_Orders::Events::OrderCreated")
      expect(order.private_methods).to include(:"on_Orders::Events::OrderExpired")

      expect(order_with_ons.on_methods.keys).to include("Orders::Events::OrderCreated")
      expect(order_with_ons.on_methods.keys).to include("Orders::Events::OrderExpired")

      order = inherited_order_with_ons.new
      order.apply(Orders::Events::OrderCreated.new)
      expect(order.status).to eq(:created_inherited)
      order.apply(Orders::Events::OrderExpired.new)
      expect(order.status).to eq(:expired)
      order.apply(Orders::Events::OrderCanceled.new)
      expect(order.status).to eq(:canceled_inherited)

      expect(order.private_methods).to include(:"on_Orders::Events::OrderCreated")
      expect(order.private_methods).to include(:"on_Orders::Events::OrderExpired")
      expect(order.private_methods).to include(:"on_Orders::Events::OrderCanceled")

      expect(inherited_order_with_ons.on_methods.keys).to include("Orders::Events::OrderCreated")
      expect(inherited_order_with_ons.on_methods.keys).to include("Orders::Events::OrderExpired")
      expect(inherited_order_with_ons.on_methods.keys).to include("Orders::Events::OrderCanceled")
    end

    it "handles super() with inheritance" do
      order_with_ons = Class.new do
        include AggregateRoot

        on Orders::Events::OrderCreated do |_ev|
          @status ||= []
          @status << :base_created
        end

        on Orders::Events::OrderExpired do |_ev|
          @status ||= []
          @status << :base_expired
        end

        attr_accessor :status
      end

      inherited_order_with_ons = Class.new(order_with_ons) do
        on Orders::Events::OrderCreated do |ev|
          super(ev)
          @status << :inherited_created
        end

        on Orders::Events::OrderExpired do |ev|
          @status.clear
          super(ev)
          @status << :inherited_expired
        end
      end

      order = inherited_order_with_ons.new
      order.apply(Orders::Events::OrderCreated.new)
      expect(order.status).to eq([:base_created, :inherited_created])
      order.apply(Orders::Events::OrderExpired.new)
      expect(order.status).to eq([:base_expired, :inherited_expired])
    end

    it "does not support anonymous events" do
      expect do
        Class.new do
          include AggregateRoot

          on(Class.new) do |_ev|
          end
        end
      end.to raise_error(ArgumentError, "Anonymous class is missing name")
    end
  end

  describe "#initialize" do
    it "allows default initializer" do
      aggregate_klass = Class.new do
        include AggregateRoot
        def initialize
          @state = :draft
        end
        attr_reader :state
      end

      aggregate = aggregate_klass.new
      expect(aggregate.state).to eq(:draft)
    end

    it "allows initializer with arguments" do
      aggregate_klass = Class.new do
        include AggregateRoot
        def initialize(a, b)
          @state = a + b
        end
        attr_reader :state
      end

      aggregate = aggregate_klass.new(2,3)
      expect(aggregate.state).to eq(5)
    end

    it "allows initializer with keyword arguments" do
      aggregate_klass = Class.new do
        include AggregateRoot
        def initialize(a:, b:)
          @state = a + b
        end
        attr_reader :state
      end

      aggregate = aggregate_klass.new(a: 2, b: 3)
      expect(aggregate.state).to eq(5)
    end

    it "allows initializer with variable arguments" do
      aggregate_klass = Class.new do
        include AggregateRoot
        def initialize(*args)
          @state = args.reduce(:+)
        end
        attr_reader :state
      end

      aggregate = aggregate_klass.new(1,2,3)
      expect(aggregate.state).to eq(6)
    end

    it "allows initializer with variable keyword arguments" do
      aggregate_klass = Class.new do
        include AggregateRoot
        def initialize(**args)
          @state = args.values.reduce(:+)
        end
        attr_reader :state
      end

      aggregate = aggregate_klass.new(a: 1, b: 2, c: 3)
      expect(aggregate.state).to eq(6)
    end

    it "allows initializer with mixed arguments" do
      aggregate_klass = Class.new do
        include AggregateRoot
        def initialize(a, *args, b:, **kwargs)
          @state = a + b + args.reduce(:+) + kwargs.values.reduce(:+)
        end
        attr_reader :state
      end

      aggregate = aggregate_klass.new(1, 2, 3, b: 4, c: 5, d: 6)
      expect(aggregate.state).to eq(21)
    end

    it "allows initializer with block" do
      aggregate_klass = Class.new do
        include AggregateRoot
        def initialize(a, *args, b:, **kwargs, &block)
          @state = block.call(a + b + args.reduce(:+) + kwargs.values.reduce(:+))
        end
        attr_reader :state
      end

      aggregate = aggregate_klass.new(1, 2, 3, b: 4, c: 5, d: 6) do |val|
        val * 2
      end
      expect(aggregate.state).to eq(42)
    end
  end
end
