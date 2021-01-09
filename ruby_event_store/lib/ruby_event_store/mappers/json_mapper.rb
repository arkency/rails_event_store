# frozen_string_literal: true

module RubyEventStore
  module Mappers
    class JSONMapper < Default
      def initialize
        warn <<~EOW
          Please replace RubyEventStore::Mappers::JSONMapper with RubyEventStore::Mappers::Default

          They're now identical and the former will be removed in next major release.
        EOW
        super
      end
    end
  end
end
