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
      end
    end
  end
end
