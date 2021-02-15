require 'spec_helper'
require 'openssl'

module RubyEventStore
  module Mappers
    RSpec.describe InMemoryEncryptionKeyRepository do
      specify "#inspect" do
        key_repository = InMemoryEncryptionKeyRepository.new
        object_id = key_repository.object_id.to_s(16)
        expect(key_repository.inspect).to eq("#<RubyEventStore::Mappers::InMemoryEncryptionKeyRepository:0x#{object_id}>")
      end
    end
  end
end
