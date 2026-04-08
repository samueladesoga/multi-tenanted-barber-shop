class CreateSalons < ActiveRecord::Migration[8.1]
  def change
    create_table :salons do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.string :owner_name, null: false
      t.string :owner_email, null: false
      t.integer :loyalty_threshold, null: false, default: 10
      t.integer :chair_count, null: false, default: 1

      t.timestamps
    end
    add_index :salons, :subdomain, unique: true
  end
end
