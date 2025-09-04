class CreateCostTrackings < ActiveRecord::Migration[8.0]
  def change
    create_table :cost_trackings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :request_id
      t.string :ai_model_used
      t.integer :input_tokens
      t.integer :output_tokens
      t.decimal :cost_estimate
      t.string :purpose

      t.timestamps
    end
  end
end
