class AddMultiDayFieldsToSeatingArrangements < ActiveRecord::Migration[8.0]
  def change
    add_column :seating_arrangements, :day_number, :integer
    add_column :seating_arrangements, :multi_day_metadata, :jsonb, default: '{}'
    
    # Add indexes for multi-day queries
    add_index :seating_arrangements, [:seating_event_id, :day_number], unique: false
    add_index :seating_arrangements, :multi_day_metadata, using: :gin
  end
end
