class AddEditorFieldsToSeatingArrangement < ActiveRecord::Migration[8.0]
  def change
    add_column :seating_arrangements, :last_modified_at, :datetime
    add_reference :seating_arrangements, :last_modified_by, null: true, foreign_key: { to_table: :users }
    add_column :seating_arrangements, :is_locked, :boolean, default: false
    add_reference :seating_arrangements, :locked_by, null: true, foreign_key: { to_table: :users }
    add_column :seating_arrangements, :locked_at, :datetime
  end
end
