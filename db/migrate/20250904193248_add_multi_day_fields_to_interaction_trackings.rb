class AddMultiDayFieldsToInteractionTrackings < ActiveRecord::Migration[8.0]
  def change
    add_column :interaction_trackings, :interaction_details, :jsonb, default: '[]'
    
    # Add index for JSON queries
    add_index :interaction_trackings, :interaction_details, using: :gin
    
    # Add index for querying specific days
    add_index :interaction_trackings, "(interaction_details->>'day')", name: 'index_interaction_trackings_on_day'
  end
end
