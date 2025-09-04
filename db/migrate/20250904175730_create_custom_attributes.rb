class CreateCustomAttributes < ActiveRecord::Migration[8.0]
  def change
    create_table :custom_attributes do |t|
      t.string :name
      t.text :description
      t.boolean :inference_enabled
      t.text :inference_prompt
      t.decimal :weight_in_optimization
      t.string :display_color
      t.boolean :active

      t.timestamps
    end
  end
end
