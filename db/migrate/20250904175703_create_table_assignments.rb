class CreateTableAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :table_assignments do |t|
      t.references :seating_arrangement, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.integer :table_number
      t.integer :seat_position
      t.boolean :locked

      t.timestamps
    end
  end
end
