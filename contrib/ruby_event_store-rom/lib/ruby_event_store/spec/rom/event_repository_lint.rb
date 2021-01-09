require 'ruby_event_store/rom/event_repository'
require 'ruby_event_store/spec/event_repository_lint'

module RubyEventStore
  module ROM
    RSpec.shared_examples :rom_event_repository do
      include_examples :event_repository
      let(:repository) { EventRepository.new(rom: env, serializer: serializer) }
      let(:helper)     { rom_helper }
      let(:serializer) {
        case ENV['DATA_TYPE']
        when /json/
          JSON
        else
          YAML
        end
      }

      around(:each) do |example|
        rom_helper.run_lifecycle { example.run }
      end

      let(:rom_helper)     { raise "provide rom_helper instance" }
      let(:env)            { rom_helper.env }
      let(:rom_container)  { env.rom_container }
      let(:specification)  { Specification.new(SpecificationReader.new(repository, ::RubyEventStore::Mappers::Default.new)) }

      specify '#initialize requires ROM::Env' do
        expect { EventRepository.new(rom: nil, serializer: serializer) }.to raise_error do |err|
          expect(err).to be_a(ArgumentError)
          expect(err.message).to eq('Must specify rom')
        end
      end

      specify '#initialize uses ROM.env by default' do
        expect { EventRepository.new(serializer: serializer) }.to raise_error(ArgumentError)
        ROM.env = env
        expect { EventRepository.new(serializer: serializer) }.not_to raise_error
        ROM.env = nil
      end

      specify '#has_event? to raise exception for bad ID' do
        expect(repository.has_event?('0')).to eq(false)
      end

      specify 'explicit sorting by position rather than accidental' do
        events = [
          SRecord.new(event_id: u1 = SecureRandom.uuid),
          SRecord.new(event_id: u2 = SecureRandom.uuid),
          SRecord.new(event_id: u3 = SecureRandom.uuid)
        ].map{|r| r.serialize(serializer) }

        repo = Repositories::Events.new(rom_container)
        repo.create_changeset(events).commit

        expect(repo.events.to_a.size).to eq(3)

        repo.stream_entries.changeset(Changesets::CreateStreamEntries, [
          { stream: 'stream', event_id: events[1].event_id, position: 1 },
          { stream: 'stream', event_id: events[0].event_id, position: 0 },
          { stream: 'stream', event_id: events[2].event_id, position: 2 }
        ]).commit

        expect(repo.stream_entries.to_a.size).to eq(3)

        expect(repository.read(specification.stream('stream').limit(3).result).map(&:event_id)).to eq([u1, u2, u3])
        expect(repository.read(specification.stream('stream').result).map(&:event_id)).to eq([u1, u2, u3])

        expect(repository.read(specification.stream('stream').backward.limit(3).result).map(&:event_id)).to eq([u3, u2, u1])
        expect(repository.read(specification.stream('stream').backward.result).map(&:event_id)).to eq([u3, u2, u1])
      end

      specify 'explicit sorting by id rather than accidental for all events' do
        events = [
          SRecord.new(event_id: u1 = SecureRandom.uuid),
          SRecord.new(event_id: u2 = SecureRandom.uuid),
          SRecord.new(event_id: u3 = SecureRandom.uuid)
        ].map{|r| r.serialize(serializer) }

        repo = Repositories::Events.new(rom_container)
        repo.create_changeset(events).commit

        expect(repo.events.to_a.size).to eq(3)

        repo.stream_entries.changeset(Changesets::CreateStreamEntries, [
          { stream: 'all', event_id: events[0].event_id, position: 1 },
          { stream: 'all', event_id: events[1].event_id, position: 0 },
          { stream: 'all', event_id: events[2].event_id, position: 2 }
        ]).commit

        expect(repo.stream_entries.to_a.size).to eq(3)

        expect(repository.read(specification.limit(3).result).map(&:event_id)).to eq([u1, u2, u3])
        expect(repository.read(specification.limit(3).backward.result).map(&:event_id)).to eq([u3, u2, u1])
      end

      specify 'nested transaction - events still not persisted if append failed' do
        repository.append_to_stream([
          event = SRecord.new(event_id: SecureRandom.uuid)
        ], Stream.new('stream'), ExpectedVersion.none)

        env.unit_of_work do
          expect do
            repository.append_to_stream([
              SRecord.new(event_id: '9bedf448-e4d0-41a3-a8cd-f94aec7aa763')
            ], Stream.new('stream'), ExpectedVersion.none)
          end.to raise_error(WrongExpectedEventVersion)
          expect(repository.has_event?('9bedf448-e4d0-41a3-a8cd-f94aec7aa763')).to be_falsey
          expect(repository.read(specification.limit(2).result).to_a).to eq([event])
        end
        expect(repository.has_event?('9bedf448-e4d0-41a3-a8cd-f94aec7aa763')).to be_falsey
        expect(repository.read(specification.limit(2).result).to_a).to eq([event])
      end
    end
  end
end
