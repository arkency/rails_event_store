require 'spec_helper'
require 'openssl'

module RubyEventStore
  module Mappers
    TicketTransferred = Class.new(RubyEventStore::Event) do
      def self.encryption_schema
        {
          sender: {
            name:  ->(data) { data.dig(:sender, :user_id) },
            email: ->(data) { data.dig(:sender, :user_id) },
            twitter: ->(data) { data.dig(:sender, :user_id) },
          },
          recipient: {
            name:  ->(data) { data.dig(:recipient, :user_id) },
            email: ->(data) { data.dig(:recipient, :user_id) },
            twitter: ->(data) { data.dig(:sender, :user_id) },
          }
        }
      end
    end

    TicketCancelled = Class.new(RubyEventStore::Event)

    TicketHolderEmailProvided = Class.new(RubyEventStore::Event) do
      def self.encryption_schema
        {
          email: ->(data) do
            data.fetch(:user_id)
          end
        }
      end
    end

    module Transformation
      RSpec.describe Encryption do
        let(:time)           { Time.now.utc }
        let(:key_repository) { InMemoryEncryptionKeyRepository.new }
        let(:serializer)     { YAML }
        let(:mapper)         { Encryption.new(key_repository, serializer: serializer) }
        let(:sender_id)      { SecureRandom.uuid }
        let(:recipient_id)   { SecureRandom.uuid }
        let(:event_id)       { SecureRandom.uuid }
        let(:ticket_id)      { SecureRandom.uuid }
        let(:correlation_id) { SecureRandom.uuid }
        let(:sender_email)   { 'alice@universe' }
        let(:recipient) do
          {
            user_id: recipient_id,
            name: 'Bob',
            email: 'bob@universe',
            twitter: nil
          }
        end
        let(:sender) do
          {
            user_id: sender_id,
            name: 'Alice',
            email: sender_email,
            twitter: '@alice'
          }
        end
        let(:data) do
          {
            ticket_id: ticket_id,
            sender: sender,
            recipient: recipient
          }
        end
        let(:metadata) do
          {
            correlation_id: correlation_id
          }
        end

        let(:ticket_transferred) do
          Record.new(
            event_id: event_id,
            data: data,
            metadata: metadata,
            event_type: 'RubyEventStore::Mappers::TicketTransferred',
            timestamp: time,
            valid_at:  time
          )
        end

        let(:ticket_cancelled) do
          Record.new(
            event_id: event_id,
            data: {
              ticket_id: ticket_id,
            },
            metadata: metadata,
            event_type: 'RubyEventStore::Mappers::TicketCancelled',
            timestamp: time,
            valid_at:  time
          )
        end

        def encrypt(e)
          mapper.dump(e)
        end

        def decrypt(r)
          mapper.load(r)
        end

        specify 'decrypts encrypted fields in presence of encryption keys' do
          key_repository.create(sender_id)
          key_repository.create(recipient_id)

          event = decrypt(encrypt(ticket_transferred))

          expect(event.event_id).to eq(event_id)
          expect(event.data).to eq({
            ticket_id: ticket_id,
            sender: sender,
            recipient: recipient
          })
          expect(event.metadata).to eq(metadata)
        end

        context "when encryptable event keys are missing" do
           let(:sender) do
             {
               user_id: sender_id,
               email: sender_email,
               twitter: '@alice'
             }
           end

           specify 'skip missing data keys' do
             key_repository.create(sender_id)
             key_repository.create(recipient_id)

             event = decrypt(encrypt(ticket_transferred))

             expect(event.event_id).to eq(event_id)

             expect(event.data).to eq({
               ticket_id: ticket_id,
               sender: sender,
               recipient: recipient
             })

             expect(event.metadata).to eq(metadata)
           end
         end

        specify 'obfuscates data for missing keys on decryption' do
          key_repository.create(sender_id)
          key_repository.create(recipient_id)

          record = encrypt(ticket_transferred)
          key_repository.forget(sender_id.dup)
          event  = decrypt(record)

          expect(event.event_id).to eq(event_id)
          expect(event.data).to eq({
            ticket_id: ticket_id,
            sender: {
              user_id: sender_id,
              name: ForgottenData::FORGOTTEN_DATA,
              email: ForgottenData::FORGOTTEN_DATA,
              twitter: ForgottenData::FORGOTTEN_DATA,
            },
            recipient: recipient
          })
          expect(event.metadata).to eq(metadata)
        end

        specify 'obfuscates data for incorrect keys on decryption' do
          key_repository.create(sender_id)
          key_repository.create(recipient_id)

          record = encrypt(ticket_transferred)
          key_repository.forget(sender_id)
          key_repository.create(sender_id)
          event  = decrypt(record)

          expect(event.event_id).to eq(event_id)
          expect(event.data).to eq({
            ticket_id: ticket_id,
            sender: {
              user_id: sender_id,
              name: ForgottenData::FORGOTTEN_DATA,
              email: ForgottenData::FORGOTTEN_DATA,
              twitter: ForgottenData::FORGOTTEN_DATA,
            },
            recipient: recipient
          })
          expect(event.metadata).to eq(metadata)
        end

        specify 'no-op for events without encryption schema' do
          event = decrypt(encrypt(ticket_cancelled))

          expect(event.event_id).to eq(event_id)
          expect(event.data).to eq({
            ticket_id: ticket_id
          })
          expect(event.metadata).to eq(metadata)
        end

        specify 'no encryption metadata without encryption schema' do
          record = encrypt(ticket_cancelled)
          expect(record.metadata).to eq(metadata)
        end

        specify 'raises error on encryption with missing encryption key' do
          expect do
            encrypt(ticket_transferred)
          end.to raise_error(Encryption::MissingEncryptionKey, "Could not find encryption key for '#{sender_id}'")
        end

        specify 'does not modify original event' do
          key_repository.create(sender_id)
          key_repository.create(recipient_id)

          event = ticket_transferred
          encrypt(event)

          expect(event.data.dig(:sender, :name)).to eq('Alice')
          expect(event.data.dig(:sender, :email)).to eq(sender_email)
          expect(event.data.dig(:recipient, :name)).to eq('Bob')
          expect(event.data.dig(:recipient, :email)).to eq('bob@universe')
          expect(event.metadata).not_to have_key(:encryption)
        end

        specify 'does not modify original record' do
          key_repository.create(sender_id)
          key_repository.create(recipient_id)

          record   = encrypt(ticket_transferred)
          data     = record.data.dup
          metadata = record.metadata.dup
          decrypt(record)

          expect(record.data).to     eq(data)
          expect(record.metadata).to eq(metadata)
        end

        specify 'two cryptograms of the same input and key are not alike' do
          key_repository.create(sender_id)

          record = encrypt(
            Record.new(
              event_id: event_id,
              data: {
                ticket_id: ticket_id,
                sender: sender,
                recipient: sender
              },
              metadata: metadata,
              event_type: 'RubyEventStore::Mappers::TicketTransferred',
              timestamp: time,
              valid_at:  time
            )
          )
          data = record.data

          expect(data.dig(:sender, :name)).not_to  eq(data.dig(:recipient, :name))
          expect(data.dig(:sender, :email)).not_to eq(data.dig(:recipient, :email))
        end

        specify 'handles non-nested encryption schema' do
          key_repository.create(sender_id)

          event =
            decrypt(
              encrypt(
                Record.new(
                  event_id: event_id,
                  data: {
                    ticket_id: ticket_id,
                    user_id: sender_id,
                    email: sender_email
                  },
                  metadata: metadata,
                  event_type: 'RubyEventStore::Mappers::TicketHolderEmailProvided',
                  timestamp: time,
                  valid_at:  time
                )
              )
          )

          expect(event.event_id).to eq(event_id)
          expect(event.data).to eq({
            ticket_id: ticket_id,
            user_id: sender_id,
            email: sender_email
          })
          expect(event.metadata).to eq(metadata)
        end

        specify 'handles non-string values' do
          key_repository.create(sender_id)

          event =
            decrypt(
              encrypt(
                Record.new(
                  event_id: event_id,
                  data: {
                    ticket_id: ticket_id,
                    user_id: sender_id,
                    email: [sender_email]
                  },
                  metadata: metadata,
                  event_type: 'RubyEventStore::Mappers::TicketHolderEmailProvided',
                  timestamp: time,
                  valid_at:  time
                )
              )
          )

          expect(event.event_id).to eq(event_id)
          expect(event.data).to eq({
            ticket_id: ticket_id,
            user_id: sender_id,
            email: [sender_email]
          })
          expect(event.metadata).to eq(metadata)
        end

        specify 'no-op for nil value' do
          key_repository.create(sender_id)

          record =
            encrypt(
              Record.new(
                event_id: event_id,
                data: {
                  ticket_id: ticket_id,
                  user_id: sender_id,
                  email: nil
                },
                metadata: metadata,
                event_type: 'RubyEventStore::Mappers::TicketHolderEmailProvided',
                timestamp: time,
                valid_at:  time
              )
          )
          event = decrypt(record)

          expect(event.event_id).to eq(event_id)
          expect(event.data).to eq({
            ticket_id: ticket_id,
            user_id: sender_id,
            email: nil
          })
          expect(record.data).to eq(event.data)
          expect(event.metadata).to eq(metadata)
        end

        specify 'defaults' do
          key_repository.create(sender_id)
          key_repository.create(recipient_id)
          record =
            Encryption
            .new(key_repository)
            .dump(ticket_transferred)
          event =
            Encryption
            .new(key_repository)
            .load(record)

          expect(event).to  eq(ticket_transferred)
        end

        specify 'handles decryption after changing cipher' do
          key_repository.create(sender_id)
          key_repository.create(recipient_id)

          record = encrypt(ticket_transferred)

          with_default_cipher('aes-128-gcm') do
            event = decrypt(record)

            expect(event.event_id).to eq(event_id)
            expect(event.data).to eq({
              ticket_id: ticket_id,
              sender: sender,
              recipient: recipient
            })
            expect(event.metadata).to eq(metadata)
          end
        end

        specify 'decrypted message is UTF-8 encoded' do
          key = key_repository.create('dummy')
          iv  = key.random_iv
          source_message    = 'zażółć gęślą jaźń'
          decrypted_message = key.decrypt(key.encrypt(source_message, iv), iv)

          expect(decrypted_message).to eq(source_message)
          expect(decrypted_message.encoding).to eq(Encoding::UTF_8)
        end

        specify 'allow use of non-authenticated cipher' do
          with_default_cipher('aes-256-cbc') do
            key_repository.create(sender_id)
            key_repository.create(recipient_id)

            event = decrypt(encrypt(ticket_transferred))

            expect(event.event_id).to eq(event_id)
            expect(event.data).to eq({
              ticket_id: ticket_id,
              sender: sender,
              recipient: recipient
            })
            expect(event.metadata).to eq(metadata)
          end
        end

        specify "#inspect" do
          key_repository = InMemoryEncryptionKeyRepository.new
          serializer = Class.new do
            def inspect
              "SomeSerializer"
            end
          end.new
          transformation = Encryption.new(key_repository, serializer: serializer)
          object_id = transformation.object_id.to_s(16)
          expect(transformation.inspect).to eq("#<RubyEventStore::Mappers::Transformation::Encryption:0x#{object_id} serializer=SomeSerializer key_repository=#{key_repository.inspect}>")
        end

        def with_default_cipher(cipher, &block)
          cipher_ = InMemoryEncryptionKeyRepository::DEFAULT_CIPHER
          InMemoryEncryptionKeyRepository.send(:remove_const, :DEFAULT_CIPHER)
          InMemoryEncryptionKeyRepository.const_set(:DEFAULT_CIPHER, cipher)
          block.call
        ensure
          InMemoryEncryptionKeyRepository.send(:remove_const, :DEFAULT_CIPHER)
          InMemoryEncryptionKeyRepository.const_set(:DEFAULT_CIPHER, cipher_)
        end
      end
    end
  end
end
