# =============================================================================
# Demo Salon Seed Data
# Idempotent — safe to run in any environment, any number of times.
# Run with: bin/rails db:seed
# =============================================================================

puts "Seeding demo salon..."

# -----------------------------------------------------------------------------
# Salon
# -----------------------------------------------------------------------------
salon = Salon.find_or_initialize_by(subdomain: "demo")
salon.update!(
  name:              "Chukwu's Cuts",
  owner_name:        "Emeka Chukwu",
  owner_email:       "emeka@democuts.com",
  loyalty_threshold: 5,
  chair_count:       3,
  currency:          "NGN"
)

puts "  Salon: #{salon.name} (#{salon.subdomain})"

ActsAsTenant.with_tenant(salon) do

  # ---------------------------------------------------------------------------
  # Staff
  # ---------------------------------------------------------------------------
  owner = Staff.find_or_create_by!(email: "emeka@democuts.com") do |s|
    s.name                  = "Emeka Chukwu"
    s.password              = "password123"
    s.password_confirmation = "password123"
    s.role                  = :owner
    s.salon                 = salon
  end

  tunde = Staff.find_or_create_by!(email: "tunde@democuts.com") do |s|
    s.name                  = "Tunde Adeyemi"
    s.password              = "password123"
    s.password_confirmation = "password123"
    s.role                  = :staff
    s.salon                 = salon
  end

  chioma = Staff.find_or_create_by!(email: "chioma@democuts.com") do |s|
    s.name                  = "Chioma Eze"
    s.password              = "password123"
    s.password_confirmation = "password123"
    s.role                  = :staff
    s.salon                 = salon
  end

  puts "  Staff: #{owner.name}, #{tunde.name}, #{chioma.name}"

  # ---------------------------------------------------------------------------
  # Working hours — Mon–Sat open, Sunday closed
  # ---------------------------------------------------------------------------
  hours = {
    "monday"    => { opens_at: "08:00", closes_at: "19:00", is_closed: false },
    "tuesday"   => { opens_at: "08:00", closes_at: "19:00", is_closed: false },
    "wednesday" => { opens_at: "08:00", closes_at: "19:00", is_closed: false },
    "thursday"  => { opens_at: "08:00", closes_at: "19:00", is_closed: false },
    "friday"    => { opens_at: "08:00", closes_at: "20:00", is_closed: false },
    "saturday"  => { opens_at: "09:00", closes_at: "18:00", is_closed: false },
    "sunday"    => { opens_at: "09:00", closes_at: "13:00", is_closed: true  }
  }

  hours.each do |day, attrs|
    wh = WorkingHour.find_or_initialize_by(day_of_week: day)
    wh.update!(attrs)
  end

  puts "  Working hours set"

  # ---------------------------------------------------------------------------
  # Services
  # ---------------------------------------------------------------------------
  services_data = [
    { name: "Haircut",             base_price: 3_000, duration_minutes: 30 },
    { name: "Shave",               base_price: 1_500, duration_minutes: 20 },
    { name: "Haircut & Shave",     base_price: 4_000, duration_minutes: 45 },
    { name: "Hair Wash",           base_price: 1_000, duration_minutes: 15 },
    { name: "Locs Maintenance",    base_price: 6_000, duration_minutes: 60 },
    { name: "Kids Haircut",        base_price: 2_000, duration_minutes: 20 },
  ]

  service_records = services_data.map do |attrs|
    Service.find_or_create_by!(name: attrs[:name]) do |s|
      s.base_price       = attrs[:base_price]
      s.duration_minutes = attrs[:duration_minutes]
      s.active           = true
      s.salon            = salon
    end
  end

  haircut         = service_records[0]
  shave           = service_records[1]
  haircut_shave   = service_records[2]
  locs            = service_records[4]
  kids_haircut    = service_records[5]

  puts "  Services: #{service_records.map(&:name).join(', ')}"

  # ---------------------------------------------------------------------------
  # Customers
  # ---------------------------------------------------------------------------
  customers_data = [
    { name: "Emeka Okafor",   phone_number: "+2348012345678", email: "emeka.okafor@gmail.com",   area: "Lekki",       state: "Lagos"  },
    { name: "Tunde Balogun",  phone_number: "+2348023456789", email: "tunde.balogun@yahoo.com",  area: "Ikeja",       state: "Lagos"  },
    { name: "Chidi Nwosu",    phone_number: "+2348034567890", email: "chidi.nwosu@gmail.com",    area: "Surulere",    state: "Lagos"  },
    { name: "Seun Adesanya",  phone_number: "+2348045678901", email: "",                          area: "Yaba",        state: "Lagos"  },
    { name: "Kunle Adeyemi",  phone_number: "+2348056789012", email: "kunle.a@outlook.com",      area: "Victoria Island", state: "Lagos" },
    { name: "Femi Ogunleye",  phone_number: "+2348067890123", email: "",                          area: "Ikorodu",     state: "Lagos"  },
    { name: "Biodun Ojo",     phone_number: "+2348078901234", email: "biodun.ojo@gmail.com",     area: "Ajah",        state: "Lagos"  },
    { name: "Uche Nnadi",     phone_number: "+2348089012345", email: "uche.nnadi@gmail.com",     area: "Oshodi",      state: "Lagos"  },
    { name: "Lanre Fasanya",  phone_number: "+2348090123456", email: "",                          area: "Mushin",      state: "Lagos"  },
    { name: "Dele Okonkwo",   phone_number: "+2348001234567", email: "dele.okonkwo@hotmail.com", area: "Festac",      state: "Lagos"  },
  ]

  customer_records = customers_data.map do |attrs|
    Customer.find_or_create_by!(phone_number: attrs[:phone_number]) do |c|
      c.name   = attrs[:name]
      c.email  = attrs[:email]
      c.area   = attrs[:area]
      c.state  = attrs[:state]
      c.salon  = salon
    end
  end

  puts "  Customers: #{customer_records.count} created"

  # ---------------------------------------------------------------------------
  # Visits — spread across the last 2 months to populate reports & loyalty
  # Skip if visits already exist to keep seed idempotent without duplicating.
  # ---------------------------------------------------------------------------
  if Visit.count.zero?
    today      = Date.current
    all_staff  = [ owner, tunde, chioma ]
    services   = [ haircut, shave, haircut_shave, locs, kids_haircut ]

    visit_scenarios = [
      # [ customer_index, days_ago, service, staff, price_override ]
      [ 0, 55, haircut,       tunde,  3_000 ],
      [ 0, 45, haircut,       tunde,  3_000 ],
      [ 0, 35, haircut_shave, owner,  4_000 ],
      [ 0, 20, haircut,       tunde,  3_000 ],
      [ 0, 10, haircut,       tunde,      0 ], # 5th visit — loyalty free cut

      [ 1, 50, shave,         chioma, 1_500 ],
      [ 1, 38, haircut,       tunde,  3_000 ],
      [ 1, 25, haircut_shave, owner,  4_000 ],
      [ 1,  8, haircut,       tunde,  2_500 ], # discount

      [ 2, 60, locs,          owner,  6_000 ],
      [ 2, 30, locs,          owner,  6_000 ],
      [ 2,  5, locs,          owner,  6_000 ],

      [ 3, 52, haircut,       tunde,  3_000 ],
      [ 3, 40, haircut,       chioma, 3_000 ],
      [ 3, 28, haircut_shave, owner,  4_000 ],
      [ 3, 14, haircut,       tunde,  3_000 ],
      [ 3,  3, haircut,       tunde,      0 ], # loyalty free

      [ 4, 48, haircut_shave, owner,  4_000 ],
      [ 4, 32, haircut,       tunde,  3_000 ],
      [ 4, 16, shave,         chioma, 1_500 ],

      [ 5, 44, kids_haircut,  tunde,  2_000 ],
      [ 5, 22, kids_haircut,  tunde,  2_000 ],
      [ 5,  7, kids_haircut,  tunde,  2_000 ],

      [ 6, 41, haircut,       chioma, 3_000 ],
      [ 6, 21, haircut_shave, owner,  3_500 ], # discount
      [ 6,  4, haircut,       chioma, 3_000 ],

      [ 7, 58, shave,         owner,  1_500 ],
      [ 7, 35, haircut,       tunde,  3_000 ],
      [ 7, 12, haircut_shave, chioma, 4_000 ],

      [ 8, 39, haircut,       tunde,  3_000 ],
      [ 8, 18, haircut,       tunde,  3_000 ],

      [ 9, 53, locs,          owner,  6_000 ],
      [ 9, 26, locs,          owner,  5_500 ], # discount
    ]

    visit_scenarios.each do |cust_idx, days_ago, service, staff, price|
      customer = customer_records[cust_idx]
      Visit.create!(
        salon:           salon,
        customer:        customer,
        service:         service,
        staff:           staff,
        price_charged:   price,
        is_free:         price == 0,
        visited_at:      (today - days_ago.days).noon
      )
    end

    puts "  Visits: #{Visit.count} created"
  else
    puts "  Visits: skipped (already exist)"
  end

  # ---------------------------------------------------------------------------
  # Upcoming appointments
  # ---------------------------------------------------------------------------
  if Appointment.count.zero?
    tomorrow    = Date.current + 1.day
    day_after   = Date.current + 2.days
    next_week   = Date.current + 7.days

    appt_scenarios = [
      { customer: customer_records[0], service: haircut,       staff: tunde,  at: tomorrow.to_time.change(hour: 9,  min: 0),  status: :confirmed,  booked_by: :staff_member  },
      { customer: customer_records[1], service: haircut_shave, staff: owner,  at: tomorrow.to_time.change(hour: 10, min: 0),  status: :pending,    booked_by: :customer_self },
      { customer: customer_records[2], service: locs,          staff: owner,  at: tomorrow.to_time.change(hour: 11, min: 0),  status: :confirmed,  booked_by: :staff_member  },
      { customer: customer_records[3], service: shave,         staff: chioma, at: tomorrow.to_time.change(hour: 14, min: 0),  status: :pending,    booked_by: :customer_self },
      { customer: customer_records[4], service: haircut,       staff: tunde,  at: day_after.to_time.change(hour: 9,  min: 30), status: :confirmed, booked_by: :staff_member  },
      { customer: customer_records[5], service: kids_haircut,  staff: tunde,  at: day_after.to_time.change(hour: 11, min: 0),  status: :pending,   booked_by: :customer_self },
      { customer: customer_records[6], service: haircut_shave, staff: owner,  at: next_week.to_time.change(hour: 10, min: 0),  status: :pending,   booked_by: :customer_self },
    ]

    appt_scenarios.each do |attrs|
      Appointment.create!(
        salon:        salon,
        customer:     attrs[:customer],
        service:      attrs[:service],
        staff:        attrs[:staff],
        scheduled_at: attrs[:at],
        status:       attrs[:status],
        booked_by:    attrs[:booked_by]
      )
    end

    puts "  Appointments: #{Appointment.count} created"
  else
    puts "  Appointments: skipped (already exist)"
  end

  # ---------------------------------------------------------------------------
  # Expenses — last 2 months
  # ---------------------------------------------------------------------------
  if Expense.count.zero?
    today      = Date.current
    last_month = today.prev_month

    expense_data = [
      # This month
      { category: :rent,      amount: 150_000, incurred_on: today.beginning_of_month,          description: "Shop rent — #{today.strftime('%B %Y')}" },
      { category: :wages,     amount:  80_000, incurred_on: today.beginning_of_month + 6.days, description: "Staff wages — Tunde" },
      { category: :wages,     amount:  80_000, incurred_on: today.beginning_of_month + 6.days, description: "Staff wages — Chioma" },
      { category: :supplies,  amount:  18_500, incurred_on: today.beginning_of_month + 3.days, description: "Clippers, combs, creams" },
      { category: :utilities, amount:  12_000, incurred_on: today.beginning_of_month + 4.days, description: "Electricity & water" },
      { category: :marketing, amount:   8_000, incurred_on: today.beginning_of_month + 8.days, description: "Instagram ads" },

      # Last month
      { category: :rent,      amount: 150_000, incurred_on: last_month.beginning_of_month,          description: "Shop rent — #{last_month.strftime('%B %Y')}" },
      { category: :wages,     amount:  80_000, incurred_on: last_month.beginning_of_month + 6.days, description: "Staff wages — Tunde" },
      { category: :wages,     amount:  80_000, incurred_on: last_month.beginning_of_month + 6.days, description: "Staff wages — Chioma" },
      { category: :supplies,  amount:  22_000, incurred_on: last_month.beginning_of_month + 2.days, description: "Clippers oil, disposables" },
      { category: :utilities, amount:  14_500, incurred_on: last_month.beginning_of_month + 5.days, description: "Electricity & water" },
      { category: :equipment, amount:  45_000, incurred_on: last_month.beginning_of_month + 10.days, description: "New clippers set" },
    ]

    expense_data.each do |attrs|
      Expense.create!(
        salon:       salon,
        staff:       owner,
        category:    attrs[:category],
        amount:      attrs[:amount],
        incurred_on: attrs[:incurred_on],
        description: attrs[:description]
      )
    end

    puts "  Expenses: #{Expense.count} created"
  else
    puts "  Expenses: skipped (already exist)"
  end

end

puts ""
puts "Done! Demo salon ready at http://demo.barberapp.localhost:3000"
puts "  Owner login:  emeka@democuts.com / password123"
puts "  Staff logins: tunde@democuts.com / password123"
puts "                chioma@democuts.com / password123"
