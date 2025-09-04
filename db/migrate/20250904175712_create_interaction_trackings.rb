class CreateInteractionTrackings < ActiveRecord::Migration[8.0]
  def change
    create_table :interaction_trackings do |t|
      t.references :student_a, null: false, foreign_key: { to_table: :students }
      t.references :student_b, null: false, foreign_key: { to_table: :students }
      t.references :seating_event, null: false, foreign_key: true
      t.integer :interaction_count, null: false, default: 0
      t.date :last_interaction

      t.timestamps
    end

    add_index :interaction_trackings, [:student_a_id, :student_b_id], unique: true
  end
end
