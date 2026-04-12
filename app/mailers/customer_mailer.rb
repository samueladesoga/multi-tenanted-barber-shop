class CustomerMailer < ApplicationMailer
  def loyalty_card(customer)
    @customer   = customer
    @salon      = customer.salon
    base_host   = Rails.application.config.action_mailer.default_url_options[:host]
    tenant_host = "#{@salon.subdomain}.#{base_host}"

    @card_url    = loyalty_card_url(qr_token: customer.qr_token, host: tenant_host)
    @booking_url = new_booking_url(host: tenant_host)

    mail(
      to:      customer.email,
      subject: "Your loyalty card — #{@salon.name}"
    )
  end
end
