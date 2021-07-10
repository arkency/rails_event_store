RSpec.configure do |config|
  config.around(:each, db: true) do |example|
    begin
      establish_database_connection
      begin
        ActiveRecord::Migration.drop_table("event_store_projections")
      rescue ActiveRecord::StatementInvalid
      end
      begin
        ActiveRecord::Migration.drop_table("event_store_events")
      rescue ActiveRecord::StatementInvalid
      end
      begin
        ActiveRecord::Migration.drop_table("event_store_events_in_streams")
      rescue ActiveRecord::StatementInvalid
      end
      m = Migrator.new(File.expand_path('../../lib/generators/ruby_event_store/persistent_projections/templates', __dir__))
      m.run_migration('create_event_store_projections')
      m2 = Migrator.new(File.expand_path('../../../../rails_event_store_active_record/lib/rails_event_store_active_record/generators/templates', __dir__))
      m2.run_migration('create_event_store_events')
      example.run
    end
  end
end
