class CreateImportSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :import_sessions do |t|
      t.references :cohort, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :status
      t.string :file_name
      t.integer :file_size
      t.datetime :processed_at

      t.timestamps
    end
  end
end
