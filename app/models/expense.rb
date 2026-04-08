class Expense < ApplicationRecord
  belongs_to :salon
  belongs_to :staff

  acts_as_tenant :salon

  enum :category, {
    rent:      0,
    supplies:  1,
    utilities: 2,
    wages:     3,
    marketing: 4,
    equipment: 5,
    other:     6
  }

  validates :amount, numericality: { greater_than: 0 }
  validates :category, presence: true
  validates :incurred_on, presence: true

  scope :for_month, ->(year, month) {
    where(incurred_on: Date.new(year, month).beginning_of_month..Date.new(year, month).end_of_month)
  }
  scope :this_month, -> { for_month(Date.today.year, Date.today.month) }

  def category_label = category.humanize
end
