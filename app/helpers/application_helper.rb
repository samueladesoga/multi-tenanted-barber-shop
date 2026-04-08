module ApplicationHelper
  include Chartkick::Helper

  # Format a monetary amount using the current salon's configured currency.
  # Falls back to NGN if no salon is set (e.g. on the marketing page).
  #
  #   format_currency(1500)       # => "₦1,500"
  #   format_currency(20.00)      # => "₦20" (NGN has precision: 0)
  def format_currency(amount)
    opts = currency_options
    number_to_currency(amount, **opts)
  end

  private
    def currency_options
      code = Current.salon&.currency || "NGN"
      Salon::SUPPORTED_CURRENCIES.fetch(code, Salon::SUPPORTED_CURRENCIES["NGN"])
        .merge(format: "%u%n")
    end
end
