# frozen_string_literal: true

class CreateEventStoreProjections < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table(:event_store_projections, force: false) do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0
    end
    add_index :event_store_projections, :name, unique: true
  end
end
