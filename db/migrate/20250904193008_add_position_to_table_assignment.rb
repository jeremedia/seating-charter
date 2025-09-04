class AddPositionToTableAssignment < ActiveRecord::Migration[8.0]
  def change
    add_column :table_assignments, :position, :integer
  end
end
