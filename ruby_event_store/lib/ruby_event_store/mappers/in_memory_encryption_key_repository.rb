# frozen_string_literal: true

module RubyEventStore
  module Mappers
    class InMemoryEncryptionKeyRepository
      DEFAULT_CIPHER = 'aes-256-gcm'.freeze

      def initialize
        @keys = {}
      end

      def key_of(identifier, cipher: DEFAULT_CIPHER)
        @keys[[identifier, cipher]]
      end

      def create(identifier, cipher: DEFAULT_CIPHER)
        crypto = prepare_encrypt(cipher)
        @keys[[identifier, cipher]] = EncryptionKey.new(cipher: cipher, key: crypto.random_key)
      end

      def forget(identifier)
        @keys = @keys.reject { |(id, _)| id.eql?(identifier) }
      end

      def inspect
        "#<#{self.class}:0x#{__id__.to_s(16)}>"
      end

      private

      def prepare_encrypt(cipher)
        crypto = OpenSSL::Cipher.new(cipher)
        crypto.encrypt
        crypto
      end
    end
  end
end
