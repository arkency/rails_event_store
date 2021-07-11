module RailsEventStore
  module Skylight
    class Dispatcher < ::Skylight::Core::Normalizers::Normalizer
      register "call.dispatcher.rails_event_store"

      CAT = "app.rails_event_store.dispatcher".freeze

      def normalize(_trace, _name, payload)
        [CAT, "#{payload[:subscriber]}#call", "Handle #{payload[:event].type}"]
      end
    end
  end
end
