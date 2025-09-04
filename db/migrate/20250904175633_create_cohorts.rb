class CreateCohorts < ActiveRecord::Migration[8.0]
  def change
    create_table :cohorts do |t|
      t.string :name, null: false
      t.text :description
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.references :user, null: false, foreign_key: true
      t.integer :max_students, null: false, default: 40

      t.timestamps
    end
  end
end
