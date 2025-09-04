class AddExplanationDataToSeatingArrangements < ActiveRecord::Migration[8.0]
  def change
    add_column :seating_arrangements, :explanation_data, :jsonb, default: {}
    add_column :seating_arrangements, :decision_log_data, :jsonb, default: {}
    add_column :seating_arrangements, :confidence_scores, :jsonb, default: {}
    
    # Add indexes for better query performance
    add_index :seating_arrangements, :explanation_data, using: :gin
    add_index :seating_arrangements, :decision_log_data, using: :gin
    add_index :seating_arrangements, :confidence_scores, using: :gin
  end
end
