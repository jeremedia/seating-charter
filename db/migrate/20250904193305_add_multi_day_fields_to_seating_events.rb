class AddMultiDayFieldsToSeatingEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :seating_events, :multi_day_metrics, :jsonb, default: '{}'
    add_column :seating_events, :multi_day_optimization_completed_at, :datetime
    add_column :seating_events, :multi_day_optimization_created_by, :integer
    
    # Add foreign key constraint for created_by
    add_foreign_key :seating_events, :users, column: :multi_day_optimization_created_by
    
    # Add indexes
    add_index :seating_events, :multi_day_optimization_completed_at
    add_index :seating_events, :multi_day_metrics, using: :gin
  end
end
