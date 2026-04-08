class WorkingHour < ApplicationRecord
  belongs_to :salon

  acts_as_tenant :salon

  enum :day_of_week, {
    monday: 0, tuesday: 1, wednesday: 2, thursday: 3,
    friday: 4, saturday: 5, sunday: 6
  }

  DAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze

  validates :day_of_week, presence: true, uniqueness: { scope: :salon_id }
  validates :opens_at, presence: true, unless: :is_closed?
  validates :closes_at, presence: true, unless: :is_closed?
end
