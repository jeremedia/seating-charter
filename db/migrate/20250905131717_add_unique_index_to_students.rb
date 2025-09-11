class AddUniqueIndexToStudents < ActiveRecord::Migration[8.0]
  def change
    # Add unique constraint on name and cohort_id combination
    add_index :students, [:name, :cohort_id], unique: true, 
              name: 'index_students_on_name_and_cohort_id'
  end
end