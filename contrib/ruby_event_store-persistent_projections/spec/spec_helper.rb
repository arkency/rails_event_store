require 'ruby_event_store'
require "ruby_event_store/persistent_projections"
require_relative '../../../support/helpers/rspec_defaults'
require_relative '../../../support/helpers/schema_helper'
require_relative '../../../support/helpers/time_enrichment'
require_relative './support/db'
require 'rails'
require 'active_support/testing/time_helpers.rb'

RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
  config.after(:each) { travel_back }
end

$verbose = ENV.has_key?('VERBOSE') ? true : false
ActiveRecord::Schema.verbose = $verbose

ENV['DATABASE_URL'] ||= 'sqlite3::memory:'

class TickingClock
  def initialize(start: Time.now.utc, tick_by: 1)
    @start = start.change(usec: start.usec)
    @next = @start.dup
    @tick_by = tick_by
  end

  def now
    current = @next.dup
    @next += tick_by
    current
  end

  def tick(index)
    start.dup + index * tick_by
  end

  attr_reader :start, :tick_by
end
