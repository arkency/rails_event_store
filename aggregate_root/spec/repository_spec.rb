# frozen_string_literal: true

require 'spec_helper'

module AggregateRoot
  RSpec.describe Repository do
    let(:event_store) { RubyEventStore::Client.new(repository: RubyEventStore::InMemoryRepository.new, mapper: RubyEventStore::Mappers::NullMapper.new) }
    let(:uuid)        { SecureRandom.uuid }
    let(:stream_name) { "Order$#{uuid}" }
    let(:repository)  { AggregateRoot::Repository.new(event_store) }

    describe "#load" do
      specify do
        event_store.publish(Orders::Events::OrderCreated.new, stream_name: stream_name)
        order = repository.load(Order.new(uuid), stream_name)

        expect(order.status).to eq(:created)
      end

      specify do
        event_store.publish(Orders::Events::OrderCreated.new, stream_name: stream_name)
        order = repository.load(Order.new(uuid), stream_name)

        expect(order.unpublished_events.to_a).to be_empty
      end

      specify do
        event_store.publish(Orders::Events::OrderCreated.new, stream_name: stream_name)
        event_store.publish(Orders::Events::OrderExpired.new, stream_name: stream_name)
        order = repository.load(Order.new(uuid), stream_name)

        expect(order.version).to eq(1)
      end

      specify do
        event_store.publish(Orders::Events::OrderCreated.new, stream_name: stream_name)
        event_store.publish(Orders::Events::OrderExpired.new, stream_name: 'dummy')
        order = repository.load(Order.new(uuid), stream_name)

        expect(order.version).to eq(0)
      end
    end

    describe "#store" do
      specify do
        order_created = Orders::Events::OrderCreated.new
        order_expired = Orders::Events::OrderExpired.new
        order         = Order.new(uuid)
        order.apply(order_created)
        order.apply(order_expired)

        allow(event_store).to receive(:publish)
        repository.store(order, stream_name)

        expect(order.unpublished_events.to_a).to be_empty
        expect(event_store).to have_received(:publish).with([order_created, order_expired], stream_name: stream_name, expected_version: -1)
        expect(event_store).not_to have_received(:publish).with(kind_of(Enumerator), any_args)
      end

      it "updates aggregate stream position and uses it in subsequent publish call as expected_version" do
        order_created = Orders::Events::OrderCreated.new
        order = Order.new(uuid)
        order.apply(order_created)

        expect(event_store).to receive(:publish).with(
          [order_created],
          stream_name:      stream_name,
          expected_version: -1
        )
        repository.store(order, stream_name)

        order_expired = Orders::Events::OrderExpired.new
        order.apply(order_expired)

        expect(event_store).to receive(:publish).with(
          [order_expired],
          stream_name:      stream_name,
          expected_version: 0
        )
        repository.store(order, stream_name)
      end
    end

    describe "#with_aggregate" do
      specify do
        order_expired = Orders::Events::OrderExpired.new
        repository.with_aggregate(Order.new(uuid), stream_name) do |order|
          order.apply(order_expired)
        end

        expect(event_store.read.stream(stream_name).last).to eq(order_expired)
      end
    end
  end
end
