module RailsEventStore
  module Skylight
    module Repository
      class Read < ::Skylight::Core::Normalizers::Normalizer
        register "read.repository.rails_event_store"

        CAT = "app.rails_event_store.repository.read".freeze

        def normalize(_trace, _name, payload)
          [CAT, "Repository#read", nil]
        end
      end

      class AppendToStream < ::Skylight::Core::Normalizers::Normalizer
        register "append_to_stream.repository.rails_event_store"

        CAT = "app.rails_event_store.repository.append_to_stream".freeze

        def normalize(_trace, _name, payload)
          [CAT, "Repository#append_to_stream", "#{payload[:stream].name}"]
        end
      end

      class LinkToStream < ::Skylight::Core::Normalizers::Normalizer
        register "link_to_stream.repository.rails_event_store"

        CAT = "app.rails_event_store.repository.link_to_stream".freeze

        def normalize(_trace, _name, payload)
          [CAT, "Repository#link_to_stream", "#{payload[:stream].name}"]
        end
      end
    end
  end
end
