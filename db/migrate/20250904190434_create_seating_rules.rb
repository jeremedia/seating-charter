class CreateSeatingRules < ActiveRecord::Migration[8.0]
  def change
    create_table :seating_rules do |t|
      t.references :seating_event, null: false, foreign_key: true
      t.string :rule_type, null: false
      t.text :natural_language_input, null: false
      t.jsonb :parsed_rule, default: {}
      t.decimal :confidence_score, precision: 5, scale: 4, default: 0.0
      t.jsonb :target_attributes, default: {}
      t.jsonb :constraints, default: {}
      t.integer :priority, default: 1
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :seating_rules, :rule_type
    add_index :seating_rules, :active
    add_index :seating_rules, :priority
    add_index :seating_rules, :confidence_score
    add_index :seating_rules, [:seating_event_id, :active]
  end
end
