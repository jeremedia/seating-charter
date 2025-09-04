class CreateSeatingArrangements < ActiveRecord::Migration[8.0]
  def change
    create_table :seating_arrangements do |t|
      t.references :seating_event, null: false, foreign_key: true
      t.jsonb :optimization_scores
      t.jsonb :arrangement_data
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.jsonb :diversity_metrics

      t.timestamps
    end
  end
end
