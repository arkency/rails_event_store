# frozen_string_literal: true

require_relative "lib/ruby_event_store/persistent_projections/version"

Gem::Specification.new do |spec|
  spec.name             = "ruby_event_store-persistent_projections"
  spec.version          = RubyEventStore::PersistentProjections::VERSION
  spec.license          = "MIT"
  spec.author           = "Arkency"
  spec.email            = "dev@arkency.com"
  spec.summary          = "Active Record based projections for Ruby Event Store"
  spec.homepage         = "https://railseventstore.org"
  spec.files            = Dir["lib/**/*"]
  spec.require_paths    = %w[lib]
  spec.extra_rdoc_files = %w[README.md]
  spec.bindir           = "bin"
  spec.executables      = %w[res_projections]

  spec.metadata = {
    "homepage_uri"    => spec.homepage,
    "source_code_uri" => "https://github.com/RailsEventStore/rails_event_store",
    "bug_tracker_uri" => "https://github.com/RailsEventStore/rails_event_store/issues",
  }

  spec.required_ruby_version = ">= 2.5"

  spec.add_dependency "ruby_event_store", ">= 1.0.0"
  spec.add_dependency "activerecord", ">= 5.2"
end
