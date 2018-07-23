class CreateEventStoreEvents < ActiveRecord::Migration<%= migration_version %>
  def change
    postgres = ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
    sqlite   = ActiveRecord::Base.connection.adapter_name == "SQLite"
    enable_extension "pgcrypto" if postgres
    create_table(:event_store_events_in_streams, force: false) do |t|
      t.string      :stream,      null: false
      t.integer     :position,    null: true
      if postgres
        t.references :event, null: false, type: :uuid
      else
        t.references :event, null: false, type: :string
      end
      t.datetime    :created_at,  null: false
    end
    add_index :event_store_events_in_streams, [:stream, :position], unique: true
    add_index :event_store_events_in_streams, [:created_at]
    add_index :event_store_events_in_streams, [:stream, :event_id], unique: true

    if postgres
      create_table(:event_store_events, id: :uuid, default: 'gen_random_uuid()', force: false) do |t|
        t.string   :event_type, null: false
        t.text     :metadata
        t.text     :data,       null: false
        t.datetime :created_at, null: false
        t.serial   :position,   null: false
      end
    else
      create_table(:event_store_events, id: false, force: false) do |t|
        t.string   :id,         null: false, limit: 36
        t.string   :event_type, null: false
        t.text     :metadata
        t.text     :data,       null: false
        t.datetime :created_at, null: false
        t.integer :position, null: false, primary_key: true, auto_increment: true
      end
      add_index :event_store_events, :id, unique: true
    end
    add_index :event_store_events, :created_at
    add_index :event_store_events, :position, unique: true
  end
end
