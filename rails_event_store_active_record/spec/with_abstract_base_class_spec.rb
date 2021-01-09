require 'spec_helper'
require 'ruby_event_store'
require 'ruby_event_store/spec/event_repository_lint'

module RailsEventStoreActiveRecord
  RSpec.describe WithAbstractBaseClass do
    include SchemaHelper

    specify 'Base for event factory models must be an abstract class' do
      NonAbstractClass = Class.new(ActiveRecord::Base)
      expect {
        WithAbstractBaseClass.new(NonAbstractClass)
      }.to raise_error(ArgumentError)
       .with_message('RailsEventStoreActiveRecord::NonAbstractClass must be an abstract class that inherits from ActiveRecord::Base')
    end

    specify 'Base for event factory models could not be the ActiveRecord::Base' do
      expect {
        WithAbstractBaseClass.new(ActiveRecord::Base)
      }.to raise_error(ArgumentError)
       .with_message('ActiveRecord::Base must be an abstract class that inherits from ActiveRecord::Base')
    end

    specify 'Base for event factory models must inherit from ActiveRecord::Base' do
      expect {
        WithAbstractBaseClass.new(Object)
      }.to raise_error(ArgumentError)
       .with_message('Object must be an abstract class that inherits from ActiveRecord::Base')
    end

    specify 'AR classes must have the same instance id' do
      event_klass, stream_klass = WithAbstractBaseClass.new(CustomApplicationRecord).call

      expect(event_klass.name).to match(/^Event_[a-z,0-9]{32}$/)
      expect(stream_klass.name).to match(/^EventInStream_[a-z,0-9]{32}$/)
      expect(event_klass.name[6..-1]).to eq(stream_klass.name[14..-1])
    end

    specify 'each factory must generate different AR classes' do
      factory1 = WithAbstractBaseClass.new(CustomApplicationRecord)
      factory2 = WithAbstractBaseClass.new(CustomApplicationRecord)
      event_klass_1, stream_klass_1 = factory1.call
      event_klass_2, stream_klass_2 = factory2.call
      expect(event_klass_1).not_to eq(event_klass_2)
      expect(stream_klass_1).not_to eq(stream_klass_2)
    end

    specify 'reading/writting works with base class' do
      begin
        establish_database_connection
        load_database_schema

        repository = EventRepository.new(model_factory: WithAbstractBaseClass.new(CustomApplicationRecord), serializer: YAML)
        repository.append_to_stream(
          [event = RubyEventStore::SRecord.new],
          RubyEventStore::Stream.new(RubyEventStore::GLOBAL_STREAM),
          RubyEventStore::ExpectedVersion.any
        )
        reader = RubyEventStore::SpecificationReader.new(repository, RubyEventStore::Mappers::Default.new)
        specification = RubyEventStore::Specification.new(reader)
        read_event = repository.read(specification.result).first
        expect(read_event).to eq(event)
      ensure
        drop_database
      end
    end

    specify 'read from declared tables' do
      begin
        establish_database_connection
        load_database_schema

        repository = EventRepository.new(model_factory: WithAbstractBaseClass.new(CustomApplicationRecord), serializer: YAML)
        repository.append_to_stream(
          [event = RubyEventStore::SRecord.new(event_type: 'Dummy')],
          RubyEventStore::Stream.new("some"),
          RubyEventStore::ExpectedVersion.any
        )
        reader = RubyEventStore::SpecificationReader.new(repository, RubyEventStore::Mappers::Default.new)

        expect_query(/SELECT.*FROM.*event_store_events.*/) do
          read_event = repository.read(RubyEventStore::Specification.new(reader).result).first
          expect(read_event).to eq(event)
        end

        expect_query(/SELECT.*FROM.*event_store_events_in_streams.*/) do
          read_event = repository.read(RubyEventStore::Specification.new(reader).of_type('Dummy').stream('some').result).first
          expect(read_event).to eq(event)
        end
      ensure
        drop_database
      end
    end

    private

    def count_queries(&block)
      count = 0
      counter_f = ->(_name, _started, _finished, _unique_id, payload) {
        unless %w[ CACHE SCHEMA ].include?(payload[:name])
          count += 1
        end
      }
      ActiveSupport::Notifications.subscribed(counter_f, "sql.active_record", &block)
      count
    end

    def expect_query(match, &block)
      count = 0
      counter_f = ->(_name, _started, _finished, _unique_id, payload) {
        count +=1 if match === payload[:sql]
      }
      ActiveSupport::Notifications.subscribed(counter_f, "sql.active_record", &block)
      expect(count).to eq(1)
    end
  end
end
