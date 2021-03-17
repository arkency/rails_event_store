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

      def publish_event
        Event.create!(event_id: SecureRandom.uuid, event_type: "Foo", data: {})
      end

      def global_status
        ProjectionStatus.find_by(name: Consumer::GLOBAL_POSITION_NAME)
      end
    end
  end
end
