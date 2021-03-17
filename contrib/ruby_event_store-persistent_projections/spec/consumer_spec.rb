require 'spec_helper'

module RubyEventStore
  module PersistentProjections
    RSpec.describe Consumer, db: true do
      include SchemaHelper

      let(:logger_output) { StringIO.new }
      let(:logger) { Logger.new(logger_output) }

      specify "creates projection global status if doesn't exist" do
        consumer = Consumer.new(SecureRandom.uuid, nil, logger: logger)

        consumer.one_loop

        expect(ProjectionStatus.count).to eq(1)
        expect(global_status.position).to eq(0)
      end

      specify 'global thread progresses the state if available' do
        publish_event
        consumer = Consumer.new(SecureRandom.uuid, nil, logger: logger)

        consumer.one_loop

        expect(global_status.position).to eq(1)
      end

      specify 'global thread progresses the state if event locked' do
        publish_event
        consumer = Consumer.new(SecureRandom.uuid, nil, logger: logger)
        expect(consumer).to receive(:check_event_on_position).with(1).and_raise(ActiveRecord::LockWaitTimeout)

        result = consumer.one_loop

        expect(result).to be(true)
        expect(global_status.position).to eq(0)
      end

      specify 'global thread progresses the state if event not found' do
        publish_event_and_rollback
        publish_event
        consumer = Consumer.new(SecureRandom.uuid, nil, logger: logger)

        consumer.one_loop
        result = consumer.one_loop

        expect(result).to be(true)
        expect(global_status.position).to eq(2)
      end

      def publish_event
        Event.create!(event_id: SecureRandom.uuid, event_type: "Foo", data: {})
      end

      def global_status
        ProjectionStatus.find_by(name: Consumer::GLOBAL_POSITION_NAME)
      end

      def publish_event_and_rollback
        ActiveRecord::Base.transaction do
          publish_event
          raise ActiveRecord::Rollback
        end
      end
    end
  end
end
