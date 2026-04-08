class Salon < ApplicationRecord
  has_many :staffs, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :working_hours, dependent: :destroy
  has_many :visits, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :expenses, dependent: :destroy

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: { case_sensitive: false },
                        format: { with: /\A[a-z0-9\-]+\z/, message: "only lowercase letters, numbers, and hyphens allowed" }
  validates :owner_name, presence: true
  validates :owner_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  SUPPORTED_CURRENCIES = {
    "NGN" => { unit: "₦",   separator: ".", delimiter: ",", precision: 0 },
    "GBP" => { unit: "£",   separator: ".", delimiter: ",", precision: 2 },
    "USD" => { unit: "$",   separator: ".", delimiter: ",", precision: 2 },
    "EUR" => { unit: "€",   separator: ",", delimiter: ".", precision: 2 },
    "GHS" => { unit: "₵",   separator: ".", delimiter: ",", precision: 2 },
    "KES" => { unit: "KSh", separator: ".", delimiter: ",", precision: 2 },
    "ZAR" => { unit: "R",   separator: ".", delimiter: ",", precision: 2 }
  }.freeze

  validates :loyalty_threshold, numericality: { greater_than: 0 }
  validates :chair_count, numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: SUPPORTED_CURRENCIES.keys }

  before_save :downcase_subdomain

  def working_hour_for(day)
    working_hours.find_by(day_of_week: day)
  end

  # Seeds default working hours after salon registration (all 7 days open).
  def seed_working_hours!
    WorkingHour::DAYS.each_with_index do |_day, index|
      working_hours.create!(day_of_week: index, opens_at: "09:00", closes_at: "18:00", is_closed: false)
    end
  end

  # Batch-updates working hours from the index form params hash.
  # Returns true if all records saved successfully, false otherwise.
  def update_working_hours(hours_params)
    hours_params.all? do |id, wh_params|
      wh        = working_hours.find(id)
      is_closed = wh_params[:is_closed] == "1"
      attrs     = { is_closed: is_closed }
      attrs.merge!(opens_at: wh_params[:opens_at], closes_at: wh_params[:closes_at]) unless is_closed
      wh.update(attrs)
    end
  end

  # Returns available booking slots for a given date and service duration.
  # Filters out slots that are fully booked (based on chair_count) and past times.
  def available_slots(date:, duration_minutes: 30, exclude_appointment_id: nil)
    date = date.to_date
    wh   = working_hours.find_by(day_of_week: weekday_index(date))
    return [] if wh.nil? || wh.is_closed?

    generate_slots(date, wh.opens_at, wh.closes_at, duration_minutes).reject do |slot|
      slot_in_past?(slot) || slot_fully_booked?(slot, duration_minutes, exclude_appointment_id)
    end
  end

  private
    def downcase_subdomain
      self.subdomain = subdomain&.downcase
    end

    def weekday_index(date)
      date.wday == 0 ? 6 : date.wday - 1  # Mon=0 … Sun=6 matching WorkingHour enum
    end

    def generate_slots(date, opens_at, closes_at, duration_minutes)
      start_time = date.to_time.change(hour: opens_at.hour, min: opens_at.min)
      end_time   = date.to_time.change(hour: closes_at.hour, min: closes_at.min)
      last_slot  = end_time - duration_minutes.minutes

      [].tap do |slots|
        current = start_time
        while current <= last_slot
          slots << current
          current += duration_minutes.minutes
        end
      end
    end

    def slot_fully_booked?(slot, duration_minutes, exclude_id)
      slot_end = slot + duration_minutes.minutes

      booked = appointments.active
                           .where.not(id: exclude_id)
                           .where(
                             "scheduled_at < ? AND scheduled_at + (COALESCE(services.duration_minutes, 30) * interval '1 minute') > ?",
                             slot_end, slot
                           )
                           .joins("LEFT JOIN services ON services.id = appointments.service_id")
                           .count

      booked >= chair_count
    end

    def slot_in_past?(slot)
      slot <= Time.current
    end
end
