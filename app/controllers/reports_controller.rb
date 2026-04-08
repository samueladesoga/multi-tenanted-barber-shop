class ReportsController < ApplicationController
  before_action :authenticate_staff!
  before_action :set_month

  def index
    visits   = Visit.for_month(@year, @month)
    expenses = Expense.for_month(@year, @month)

    @revenue          = visits.sum(:price_charged)
    @visit_count      = visits.count
    @free_visit_count = visits.where(is_free: true).count
    @discount_total   = visits.discounted.sum("services.base_price - visits.price_charged")

    @revenue_by_service = visits.joins(:service)
                                .group("services.name")
                                .sum(:price_charged)
                                .sort_by { |_, v| -v }

    @daily_revenue = visits.group_by_day(:visited_at,
                       range: @selected_month.beginning_of_month..@selected_month.end_of_month)
                           .sum(:price_charged)

    @total_expenses       = expenses.sum(:amount)
    @expenses_by_category = expenses.group(:category).sum(:amount)

    @daily_expenses = expenses.group_by_day(:incurred_on,
                        range: @selected_month.beginning_of_month..@selected_month.end_of_month)
                              .sum(:amount)

    @profit_loss = @revenue - @total_expenses
    @profitable  = @profit_loss >= 0
  end

  def services
    @service_stats    = Visit.service_stats_for_month(@year, @month)
    @total_revenue    = @service_stats.sum { |s| s[:total_revenue] }
    @total_discounts  = @service_stats.sum { |s| s[:total_discount] }

    @revenue_by_service_chart = @service_stats.map { |s| [ s[:name], s[:total_revenue] ] }.to_h
    @visits_by_service_chart  = @service_stats.map { |s| [ s[:name], s[:visit_count] ] }.to_h
  end

  def discounts
    discounted = Visit.for_month(@year, @month).discounted

    @discounted_visit_count = discounted.count
    @total_discount_amount  = discounted.sum("services.base_price - visits.price_charged")
    @total_revenue          = Visit.for_month(@year, @month).sum(:price_charged).to_f

    @discount_by_service = discounted.joins(:service)
                                     .group("services.name")
                                     .sum("services.base_price - visits.price_charged")
                                     .sort_by { |_, v| -v }

    @discount_by_staff = discounted.joins(:staff)
                                   .group("staffs.name")
                                   .sum("services.base_price - visits.price_charged")
                                   .sort_by { |_, v| -v }

    @discount_reasons = discounted.where.not(discount_reason: [ nil, "" ])
                                  .group(:discount_reason)
                                  .count
                                  .sort_by { |_, v| -v }

    @daily_discounts = discounted.group_by_day(:visited_at,
                         range: @selected_month.beginning_of_month..@selected_month.end_of_month)
                                 .sum("services.base_price - visits.price_charged")
  end

  private
    def set_month
      if params[:month].present?
        @year, @month = params[:month].split("-").map(&:to_i)
      else
        @year  = Date.today.year
        @month = Date.today.month
      end

      @selected_month = Date.new(@year, @month)
      @prev_month     = @selected_month.prev_month
      @next_month     = @selected_month.next_month
      @is_future      = @next_month > Date.today
    end
end
