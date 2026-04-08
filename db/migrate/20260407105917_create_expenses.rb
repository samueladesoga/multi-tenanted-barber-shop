class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :salon, null: false, foreign_key: true
      t.references :staff, null: false, foreign_key: { to_table: :staffs }
      t.decimal :amount, null: false, precision: 10, scale: 2
      t.integer :category, null: false, default: 0
      t.string :description
      t.date :incurred_on, null: false

      t.timestamps
    end
    add_index :expenses, [ :salon_id, :incurred_on ]
  end
end
