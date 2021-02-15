# frozen_string_literal: true

module RailsEventStore
  class AfterCommitAsyncDispatcher
    def initialize(scheduler:)
      @scheduler = scheduler
    end

    def call(subscriber, _, record)
      run do
        @scheduler.call(subscriber, record)
      end
    end

    def run(&schedule_proc)
      transaction = ActiveRecord::Base.connection.current_transaction

      if transaction.joinable?
        transaction.add_record(async_record(schedule_proc))
      else
        yield
      end
    end

    def async_record(schedule_proc)
      AsyncRecord.new(self, schedule_proc)
    end

    def verify(subscriber)
      @scheduler.verify(subscriber)
    end

    def inspect
      "#<#{self.class}:0x#{__id__.to_s(16)} scheduler=#{@scheduler.inspect}>"
    end

    class AsyncRecord
      def initialize(dispatcher, schedule_proc)
        @dispatcher = dispatcher
        @schedule_proc = schedule_proc
      end

      def committed!(*)
        schedule_proc.call
      end

      def rolledback!(*)
      end

      def before_committed!
      end

      def add_to_transaction
        dispatcher.run(&schedule_proc)
      end

      def trigger_transactional_callbacks?
      end

      attr_reader :schedule_proc, :dispatcher
    end
  end
end
