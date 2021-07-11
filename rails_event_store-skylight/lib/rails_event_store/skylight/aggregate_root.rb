module RailsEventStore
  module Skylight
    module AggregateRoot
      module Repository
        class Load < ::Skylight::Core::Normalizers::Normalizer
          register "load.repository.aggregate_root"

          CAT = "app.aggregate_root.repository.load".freeze

          def normalize(_trace, _name, payload)
            [CAT, "Load #{payload[:aggregate].class}", "From #{payload[:stream]}"]
          end
        end

        class Store < ::Skylight::Core::Normalizers::Normalizer
          register "store.repository.aggregate_root"

          CAT = "app.aggregate_root.repository.store".freeze

          def normalize(_trace, _name, payload)
            [CAT, "Store #{payload[:aggregate].class}", "Into #{payload[:stream]}"]
          end
        end
      end
    end
  end
end
