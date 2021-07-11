# frozen_string_literal: true

require 'concurrent'

module RubyEventStore
  class Subscriptions
    def initialize(event_type_resolver: default_event_type_resolver)
      @event_type_resolver = event_type_resolver
      @local  = LocalSubscriptions.new
      @global = GlobalSubscriptions.new
      @thread = ThreadSubscriptions.new
    end

    def add_subscription(subscriber, event_types)
      local.add(subscriber, event_types)
    end

    def add_global_subscription(subscriber)
      global.add(subscriber)
    end

    def add_thread_subscription(subscriber, event_types)
      thread.local.add(subscriber, event_types)
    end

    def add_thread_global_subscription(subscriber)
      thread.global.add(subscriber)
    end

    def all_for(event_type)
      [local, global, thread].map{|r| r.all_for(event_type)}.reduce(&:+)
    end

    attr_reader :event_type_resolver

    private
    attr_reader :local, :global, :thread

    def default_event_type_resolver
      ->(value) { value.to_s }
    end

    class ThreadSubscriptions
      def initialize
        @local  = ThreadLocalSubscriptions.new
        @global = ThreadGlobalSubscriptions.new
      end
      attr_reader :local, :global

      def all_for(event_type)
        [global, local].map{|r| r.all_for(event_type)}.reduce(&:+)
      end
    end

    class LocalSubscriptions
      def initialize
        @subscriptions = Hash.new {|hsh, key| hsh[key] = [] }
      end

      def add(subscription, event_types)
        event_types.each{ |type| @subscriptions[type] << subscription }
        ->() {event_types.each{ |type| @subscriptions.fetch(type).delete(subscription) } }
      end

      def all_for(event_type)
        @subscriptions[event_type]
      end
    end

    class GlobalSubscriptions
      def initialize
        @subscriptions = []
      end

      def add(subscription)
        @subscriptions << subscription
        ->() { @subscriptions.delete(subscription) }
      end

      def all_for(_event_type)
        @subscriptions
      end
    end

    class ThreadLocalSubscriptions
      def initialize
        @subscriptions = Concurrent::ThreadLocalVar.new do
          Hash.new {|hsh, key| hsh[key] = [] }
        end
      end

      def add(subscription, event_types)
        event_types.each{ |type| @subscriptions.value[type] << subscription }
        ->() {event_types.each{ |type| @subscriptions.value.fetch(type).delete(subscription) } }
      end

      def all_for(event_type)
        @subscriptions.value[event_type]
      end
    end

    class ThreadGlobalSubscriptions
      def initialize
        @subscriptions = Concurrent::ThreadLocalVar.new([])
      end

      def add(subscription)
        @subscriptions.value += [subscription]
        ->() { @subscriptions.value -= [subscription] }
      end

      def all_for(_event_type)
        @subscriptions.value
      end
    end
  end
end
