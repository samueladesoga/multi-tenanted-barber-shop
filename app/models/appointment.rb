class Appointment < ApplicationRecord
  belongs_to :salon
  belongs_to :customer
  belongs_to :service, optional: true
  belongs_to :staff, optional: true

  acts_as_tenant :salon

  enum :status, {
    pending:   0,
    confirmed: 1,
    completed: 2,
    cancelled: 3,
    no_show:   4
  }

  enum :booked_by, {
    customer_self: 0,
    staff_member:  1
  }

  validates :scheduled_at, presence: true
  validate  :scheduled_at_must_be_future, on: :create
  validate  :slot_must_be_available, on: :create

  scope :upcoming, -> { where(scheduled_at: Time.current..).where(status: [ :pending, :confirmed ]) }
  scope :for_date, ->(date) { where(scheduled_at: date.beginning_of_day..date.end_of_day) }
  scope :active,   -> { where(status: [ :pending, :confirmed ]) }

  def duration_minutes
    service&.duration_minutes || 30
  end

  def ends_at
    scheduled_at + duration_minutes.minutes
  end

  def convertible_to_visit?
    completed? || confirmed?
  end

  def confirm!
    update!(status: :confirmed).tap { AppointmentNotifier.notify(self, :confirmed) }
  end

  def cancel!
    update!(status: :cancelled).tap { AppointmentNotifier.notify(self, :cancelled) }
  end

  def complete!
    update!(status: :completed)
  end

  private
    def scheduled_at_must_be_future
      return unless scheduled_at
      errors.add(:scheduled_at, "must be in the future") if scheduled_at <= Time.current
    end

    def slot_must_be_available
      return unless scheduled_at && salon

      overlapping = salon.appointments.active
                         .where.not(id: id)
                         .where("scheduled_at < ? AND scheduled_at + (COALESCE(services.duration_minutes, 30) * interval '1 minute') > ?",
                                ends_at, scheduled_at)
                         .joins("LEFT JOIN services ON services.id = appointments.service_id")
                         .count

      if overlapping >= salon.chair_count
        errors.add(:scheduled_at, "that slot is fully booked")
      end
    end
end
