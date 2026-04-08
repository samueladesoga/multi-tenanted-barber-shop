class DashboardController < ApplicationController
  before_action :authenticate_staff!

  def index
    today = Date.today

    # Visits & revenue
    @visits_today        = Visit.where(visited_at: today.beginning_of_day..today.end_of_day).count
    @revenue_today       = Visit.where(visited_at: today.beginning_of_day..today.end_of_day).sum(:price_charged)
    @visits_this_month   = Visit.this_month.count
    @revenue_this_month  = Visit.this_month.sum(:price_charged)

    # Month-over-month revenue comparison
    last_month            = today.prev_month
    @revenue_last_month   = Visit.for_month(last_month.year, last_month.month).sum(:price_charged)
    @revenue_change       = @revenue_last_month > 0 ?
                              ((@revenue_this_month - @revenue_last_month) / @revenue_last_month * 100).round(1) : nil

    # Customers
    @total_customers     = Customer.count
    @near_milestone      = Customer.near_loyalty_milestone(Current.salon.loyalty_threshold).limit(5)

    # Today's appointments
    @appointments_today  = Appointment.includes(:customer, :service)
                                      .for_date(today)
                                      .where(status: %i[ pending confirmed ])
                                      .order(:scheduled_at)

    # Recent visits
    @recent_visits       = Visit.includes(:customer, :service).order(visited_at: :desc).limit(5)
  end
end
