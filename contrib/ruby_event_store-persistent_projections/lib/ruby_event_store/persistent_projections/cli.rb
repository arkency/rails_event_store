require "optparse"
require_relative "version"
require_relative "consumer"

module RubyEventStore
  module PersistentProjections
    class CLI
      Options = Struct.new(:require_file, :log_level)

      class Parser
        def self.parse(argv)
          options = Options.new(nil, nil)
          OptionParser.new do |option_parser|
            option_parser.banner = "Usage: res_projections [options]"

            option_parser.on("--require REQUIRE", "File to require, ex. ./config/environment.rb") do |require_file|
              options.require_file = require_file
            end

            option_parser.on("--log-level LOG_LEVEL", [:fatal, :error, :warn, :info, :debug], "Logging level, one of: fatal, error, warn, info, debug") do |log_level|
              options.log_level = log_level.to_sym
            end

            option_parser.on_tail("--version", "Show version") do
              puts VERSION
              exit
            end
          end.parse(argv)
          return options
        end
      end

      def run(argv)
        options = Parser.parse(argv)
        consumer = build_consumer(options)
        consumer.init
        consumer.run
      end

      def build_consumer(options)
        consumer_uuid = SecureRandom.uuid
        logger = Logger.new(STDOUT, level: options.log_level, progname: "RES-Projections #{consumer_uuid}")
        consumer = RubyEventStore::PersistentProjections::Consumer.new(
          consumer_uuid,
          options.require_file,
          logger: logger,
        )
      end
    end
  end
end
