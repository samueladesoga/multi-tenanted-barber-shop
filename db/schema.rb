# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_11_200652) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "appointments", force: :cascade do |t|
    t.integer "booked_by", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.text "notes"
    t.bigint "salon_id", null: false
    t.datetime "scheduled_at", null: false
    t.bigint "service_id"
    t.bigint "staff_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "scheduled_at"], name: "index_appointments_on_customer_id_and_scheduled_at"
    t.index ["customer_id"], name: "index_appointments_on_customer_id"
    t.index ["salon_id", "scheduled_at"], name: "index_appointments_on_salon_id_and_scheduled_at"
    t.index ["salon_id"], name: "index_appointments_on_salon_id"
    t.index ["service_id"], name: "index_appointments_on_service_id"
    t.index ["staff_id"], name: "index_appointments_on_staff_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "area"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "phone_number"
    t.string "qr_token"
    t.bigint "salon_id", null: false
    t.string "state"
    t.datetime "updated_at", null: false
    t.integer "visits_count"
    t.index ["qr_token"], name: "index_customers_on_qr_token", unique: true
    t.index ["salon_id"], name: "index_customers_on_salon_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.decimal "amount"
    t.integer "category"
    t.datetime "created_at", null: false
    t.string "description"
    t.date "incurred_on"
    t.bigint "salon_id", null: false
    t.bigint "staff_id", null: false
    t.datetime "updated_at", null: false
    t.index ["salon_id"], name: "index_expenses_on_salon_id"
    t.index ["staff_id"], name: "index_expenses_on_staff_id"
  end

  create_table "salons", force: :cascade do |t|
    t.integer "chair_count"
    t.datetime "created_at", null: false
    t.string "currency", default: "NGN", null: false
    t.integer "loyalty_threshold"
    t.string "name"
    t.string "owner_email"
    t.string "owner_name"
    t.string "subdomain"
    t.datetime "updated_at", null: false
    t.index ["subdomain"], name: "index_salons_on_subdomain", unique: true
  end

  create_table "services", force: :cascade do |t|
    t.boolean "active"
    t.decimal "base_price"
    t.datetime "created_at", null: false
    t.integer "duration_minutes"
    t.string "name"
    t.bigint "salon_id", null: false
    t.datetime "updated_at", null: false
    t.index ["salon_id"], name: "index_services_on_salon_id"
  end

  create_table "staffs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role"
    t.bigint "salon_id"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_staffs_on_email", unique: true
    t.index ["reset_password_token"], name: "index_staffs_on_reset_password_token", unique: true
    t.index ["salon_id"], name: "index_staffs_on_salon_id"
  end

  create_table "visits", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.string "discount_reason"
    t.boolean "is_free"
    t.decimal "price_charged"
    t.bigint "salon_id", null: false
    t.bigint "service_id", null: false
    t.bigint "staff_id", null: false
    t.datetime "updated_at", null: false
    t.datetime "visited_at"
    t.index ["customer_id"], name: "index_visits_on_customer_id"
    t.index ["salon_id"], name: "index_visits_on_salon_id"
    t.index ["service_id"], name: "index_visits_on_service_id"
    t.index ["staff_id"], name: "index_visits_on_staff_id"
  end

  create_table "working_hours", force: :cascade do |t|
    t.time "closes_at"
    t.datetime "created_at", null: false
    t.integer "day_of_week"
    t.boolean "is_closed"
    t.time "opens_at"
    t.bigint "salon_id", null: false
    t.datetime "updated_at", null: false
    t.index ["salon_id"], name: "index_working_hours_on_salon_id"
  end

  add_foreign_key "appointments", "customers"
  add_foreign_key "appointments", "salons"
  add_foreign_key "appointments", "services"
  add_foreign_key "appointments", "staffs"
  add_foreign_key "customers", "salons"
  add_foreign_key "expenses", "salons"
  add_foreign_key "expenses", "staffs"
  add_foreign_key "services", "salons"
  add_foreign_key "visits", "customers"
  add_foreign_key "visits", "salons"
  add_foreign_key "visits", "services"
  add_foreign_key "visits", "staffs"
  add_foreign_key "working_hours", "salons"
end
