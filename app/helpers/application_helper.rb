module ApplicationHelper
  include Chartkick::Helper

  # Format a monetary amount using the current salon's configured currency.
  # Falls back to NGN if no salon is set (e.g. on the marketing page).
  #
  #   format_currency(1500)       # => "₦1,500"
  #   format_currency(20.00)      # => "₦20" (NGN has precision: 0)
  # Renders a customer's QR code as a sanitized SVG tag.
  # Sanitizing prevents XSS even though the SVG is generated server-side.
  QR_SVG_TAGS       = %w[svg rect path circle line polyline polygon g defs use symbol title desc].freeze
  QR_SVG_ATTRIBUTES = %w[viewBox xmlns width height x y cx cy r d fill stroke stroke-width
                          class id transform offset color shape-rendering module_size].freeze

  def qr_code_svg_tag(customer, url)
    sanitize(customer.qr_code_svg(url), tags: QR_SVG_TAGS, attributes: QR_SVG_ATTRIBUTES)
  end

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
