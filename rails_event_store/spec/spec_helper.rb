require 'rails_event_store'
require 'example_invoicing_app'
require 'support/fake_configuration'
require 'active_record'
require 'securerandom'
require 'rails/gem_version'
require_relative '../../support/helpers/rspec_defaults'
require_relative '../../support/helpers/migrator'
require_relative '../../support/helpers/silence_stdout'
require_relative '../../support/helpers/time_enrichment'

RSpec.configure do |config|
  config.around(:each) do |example|
    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
    m = Migrator.new(File.expand_path('../../rails_event_store_active_record/lib/rails_event_store_active_record/generators/templates', __dir__))
    m.run_migration('create_event_store_events')
    example.run
  end

  config.around(:each) do |example|
    ActiveJob::Base.queue_adapter = :inline
    example.run
  end
end

$verbose = ENV.has_key?('VERBOSE') ? true : false
ActiveJob::Base.logger = nil unless $verbose
ActiveRecord::Schema.verbose = $verbose

DummyEvent = Class.new(RubyEventStore::Event)

module GeneratorHelper
  def dummy_app_name
    "dummy_#{Rails::VERSION::MAJOR}_#{Rails::VERSION::MINOR}"
  end

  def dummy_app_root
    File.join(__dir__, dummy_app_name)
  end

  def destination_root
    @destination_root ||= File.join(File.join(__dir__, 'tmp'), SecureRandom.hex)
  end

  def prepare_destination_root
    FileUtils.mkdir_p(destination_root)
    raise "App #{dummy_app_name} doesn't exist" unless File.exist?(dummy_app_root)
    FileUtils.cp_r("#{dummy_app_root}/.", destination_root)
  end

  def nuke_destination_root
    FileUtils.rm_r(destination_root)
  end

  def run_generator(generator_args)
    SilenceStdout.silence_stdout { ::RailsEventStore::Generators::BoundedContextGenerator.start(generator_args, destination_root: destination_root) }
  end

  def system_run_generator(genetator_args)
    system("cd #{destination_root}; bin/rails g rails_event_store:bounded_context #{genetator_args.join(' ')} -q")
  end
end

