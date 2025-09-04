class CreateStudents < ActiveRecord::Migration[8.0]
  def change
    create_table :students do |t|
      t.string :name
      t.string :title
      t.string :organization
      t.string :location
      t.references :cohort, null: false, foreign_key: true
      t.jsonb :student_attributes
      t.jsonb :inferences
      t.jsonb :confidence_scores

      t.timestamps
    end
  end
end
