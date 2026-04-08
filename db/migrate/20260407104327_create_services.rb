class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.references :salon, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :base_price, null: false, precision: 10, scale: 2
      t.integer :duration_minutes, null: false, default: 30
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
