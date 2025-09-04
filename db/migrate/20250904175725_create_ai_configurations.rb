class CreateAiConfigurations < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_configurations do |t|
      t.string :ai_model_name
      t.string :api_endpoint
      t.decimal :temperature
      t.integer :max_tokens
      t.integer :batch_size
      t.integer :retry_attempts
      t.decimal :cost_per_token
      t.boolean :active

      t.timestamps
    end
  end
end
