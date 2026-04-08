class CreateAppointments < ActiveRecord::Migration[8.1]
  def change
    create_table :appointments do |t|
      t.references :salon, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :service, null: true, foreign_key: true
      t.references :staff, null: true, foreign_key: { to_table: :staffs }
      t.datetime :scheduled_at, null: false
      t.integer :status, null: false, default: 0
      t.integer :booked_by, null: false, default: 0
      t.text :notes

      t.timestamps
    end
    add_index :appointments, [ :salon_id, :scheduled_at ]
    add_index :appointments, [ :customer_id, :scheduled_at ]
  end
end
