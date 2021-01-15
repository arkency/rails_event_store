require 'spec_helper'
require 'action_controller/railtie'

module RailsEventStore
  RSpec.describe Client do
    TestEvent = Class.new(RailsEventStore::Event)

    specify 'has default request metadata proc if no custom one provided' do
      client = Client.new
      expect(client.request_metadata.call({
        'action_dispatch.request_id' => 'dummy_id',
        'action_dispatch.remote_ip'  => 'dummy_ip'
      })).to eq({
        remote_ip: 'dummy_ip',
        request_id: 'dummy_id'
      })
    end

    specify 'allows to set custom request metadata proc' do
      client = Client.new(
        request_metadata: -> env { {server_name: env['SERVER_NAME']} }
      )
      expect(client.request_metadata.call({
        'SERVER_NAME' => 'example.org'
      })).to eq({
        server_name: 'example.org'
      })
    end

    specify 'published event metadata will be enriched by metadata provided in request metadata when executed inside a with_request_metadata block' do
      client = Client.new(
        repository: InMemoryRepository.new,
      )
      event = TestEvent.new
      client.with_request_metadata(
        'action_dispatch.request_id' => 'dummy_id',
        'action_dispatch.remote_ip'  => 'dummy_ip'
      ) do
        client.publish(event)
      end
      published = client.read.to_a
      expect(published.size).to eq(1)
      expect(published.first.metadata[:remote_ip]).to eq('dummy_ip')
      expect(published.first.metadata[:request_id]).to eq('dummy_id')
      expect(published.first.metadata[:timestamp]).to be_a Time
    end

    specify 'wraps repository into instrumentation' do
      client = Client.new(repository: InMemoryRepository.new)

      received_notifications = 0
      ActiveSupport::Notifications.subscribe("append_to_stream.repository.ruby_event_store") do
        received_notifications += 1
      end

      client.publish(TestEvent.new)

      expect(received_notifications).to eq(1)
    end

    specify 'wraps mapper into instrumentation' do
      client = Client.new(
        repository: InMemoryRepository.new,
        mapper: RubyEventStore::Mappers::NullMapper.new
      )

      received_notifications = 0
      ActiveSupport::Notifications.subscribe("event_to_record.mapper.ruby_event_store") do
        received_notifications += 1
      end

      client.publish(TestEvent.new)

      expect(received_notifications).to eq(1)
    end

    specify "#inspect" do
      client    = Client.new
      object_id = client.object_id.to_s(16)
      expect(client.inspect).to eq("#<RailsEventStore::Client:0x#{object_id}>")
    end

    specify do
      expect { Client.new }.not_to output.to_stderr
    end
  end
end
