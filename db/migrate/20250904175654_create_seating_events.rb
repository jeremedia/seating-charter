class CreateSeatingEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :seating_events do |t|
      t.references :cohort, null: false, foreign_key: true
      t.string :name
      t.integer :event_type
      t.date :event_date
      t.integer :table_size
      t.integer :total_tables

      t.timestamps
    end
  end
end
