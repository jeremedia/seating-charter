class CreateStudentImportRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :student_import_records do |t|
      t.references :import_session, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.jsonb :raw_data
      t.jsonb :ai_inferences
      t.jsonb :corrections
      t.boolean :feedback_provided

      t.timestamps
    end
  end
end
