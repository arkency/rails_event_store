# frozen_string_literal: true

module RubyEventStore
  module RSpec
    module CrudeFailureMessageFormatter
      class HavePublished
        def initialize(differ)
          @differ = differ
        end

        def failure_message(expected, events, _stream_name)
          "expected #{expected.events} to be published, diff:" +
            differ.diff(expected.events.to_s + "\n", events.to_a)
        end

        def failure_message_when_negated(expected, events)
          "expected #{expected.events} not to be published, diff:" +
            differ.diff(expected.events.to_s + "\n", events.to_a)
        end

        private
        attr_reader :differ
      end

      class Publish
        def failure_message(expected, events, stream)
          if match_events?(expected)
            <<~EOS
            expected block to have published:

            #{expected.events}

            #{"in stream #{stream} " if stream}but published:

            #{events}
            EOS
          else
            "expected block to have published any events"
          end
        end

        def failure_message_when_negated(expected, events, stream)
          if match_events?(expected)
            <<~EOS
            expected block not to have published:

            #{expected.events}

            #{"in stream #{stream} " if stream}but published:

            #{events}
            EOS
          else
            "expected block not to have published any events"
          end
        end

        def match_events?(expected)
          !expected.events.empty?
        end
      end

      def self.have_published
        HavePublished
      end

      def self.publish
        Publish
      end
    end
  end
end
