class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.references :salon, null: false, foreign_key: true
      t.string :name, null: false
      t.string :phone_number, null: false
      t.string :email
      t.string :area
      t.string :state
      t.string :qr_token, null: false
      t.integer :visits_count, null: false, default: 0

      t.timestamps
    end
    add_index :customers, :qr_token, unique: true
    add_index :customers, [ :salon_id, :phone_number ], unique: true
  end
end
