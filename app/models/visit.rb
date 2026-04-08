class Visit < ApplicationRecord
  belongs_to :salon
  belongs_to :customer, counter_cache: :visits_count
  belongs_to :service
  belongs_to :staff

  acts_as_tenant :salon

  validates :price_charged, numericality: { greater_than_or_equal_to: 0 }
  validates :visited_at, presence: true

  before_validation :set_visited_at, on: :create
  before_create     :apply_loyalty_discount

  # -- Scopes ------------------------------------------------------------------

  scope :this_month,   -> { where(visited_at: Time.current.beginning_of_month..Time.current.end_of_month) }
  scope :for_month,    ->(year, month) { where(visited_at: Date.new(year, month).beginning_of_month..Date.new(year, month).end_of_month) }
  scope :discounted,   -> { joins(:service).where("visits.price_charged < services.base_price") }
  scope :chronologically, -> { order(visited_at: :asc) }
  scope :with_service_and_staff, -> { includes(:service, :staff) }

  # -- Reporting ---------------------------------------------------------------

  # Returns per-service stats for a given month as an array of hashes.
  def self.service_stats_for_month(year, month)
    total_revenue = for_month(year, month).sum(:price_charged).to_f

    for_month(year, month)
      .joins(:service)
      .group("services.id", "services.name", "services.base_price")
      .select(
        "services.name",
        "services.base_price",
        "COUNT(visits.id)                                      AS visit_count",
        "SUM(visits.price_charged)                             AS total_revenue",
        "AVG(visits.price_charged)                             AS avg_charged",
        "SUM(services.base_price - visits.price_charged)       AS total_discount"
      )
      .map do |r|
        {
          name:           r.name,
          base_price:     r.base_price.to_f,
          visit_count:    r.visit_count.to_i,
          total_revenue:  r.total_revenue.to_f,
          avg_charged:    r.avg_charged.to_f,
          total_discount: r.total_discount.to_f,
          revenue_share:  total_revenue > 0 ? (r.total_revenue.to_f / total_revenue * 100).round(1) : 0
        }
      end
      .sort_by { |s| -s[:total_revenue] }
  end

  # -- Instance ----------------------------------------------------------------

  def discount_amount
    service.base_price - price_charged
  end

  def discounted?
    price_charged < service.base_price
  end

  private
    def set_visited_at
      self.visited_at ||= Time.current
    end

    # Automatically mark as free when the customer hits a loyalty milestone.
    # Staff can also manually flag is_free on the form — respect that override.
    def apply_loyalty_discount
      return if is_free
      next_count = customer.visits_count + 1
      if (next_count % salon.loyalty_threshold).zero?
        self.is_free       = true
        self.price_charged = 0
      end
    end
end
