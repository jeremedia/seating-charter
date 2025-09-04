class CreateSeatingInstructions < ActiveRecord::Migration[8.0]
  def change
    create_table :seating_instructions do |t|
      t.references :seating_event, null: false, foreign_key: true
      t.text :instruction_text
      t.jsonb :parsed_constraints
      t.jsonb :ai_interpretation
      t.boolean :applied

      t.timestamps
    end
  end
end
