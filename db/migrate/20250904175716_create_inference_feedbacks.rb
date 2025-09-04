class CreateInferenceFeedbacks < ActiveRecord::Migration[8.0]
  def change
    create_table :inference_feedbacks do |t|
      t.references :student_import_record, null: false, foreign_key: true
      t.string :field_name
      t.string :original_inference
      t.string :corrected_value
      t.integer :feedback_type
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
