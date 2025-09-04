class CreateNaturalLanguageInstructions < ActiveRecord::Migration[8.0]
  def change
    create_table :natural_language_instructions do |t|
      t.references :seating_event, null: false, foreign_key: true
      t.text :instruction_text, null: false
      t.string :parsing_status, default: 'pending'
      t.jsonb :parsed_rules, default: []
      t.jsonb :ai_interpretation, default: {}
      t.decimal :confidence_score, precision: 5, scale: 4, default: 0.0
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.text :error_message

      t.timestamps
    end

    add_index :natural_language_instructions, :parsing_status
    add_index :natural_language_instructions, :confidence_score
    add_index :natural_language_instructions, [:seating_event_id, :parsing_status]
  end
end
