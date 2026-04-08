class CreateVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :visits do |t|
      t.references :salon, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :staff, null: false, foreign_key: { to_table: :staffs }
      t.decimal :price_charged, null: false, precision: 10, scale: 2
      t.string :discount_reason
      t.boolean :is_free, null: false, default: false
      t.datetime :visited_at, null: false

      t.timestamps
    end
  end
end
