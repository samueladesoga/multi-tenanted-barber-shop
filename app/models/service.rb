class Service < ApplicationRecord
  belongs_to :salon
  has_many :visits, dependent: :restrict_with_error

  acts_as_tenant :salon

  validates :name, presence: true
  validates :base_price, numericality: { greater_than_or_equal_to: 0 }
  validates :duration_minutes, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
end
