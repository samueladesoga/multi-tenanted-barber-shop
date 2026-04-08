# Sends SMS messages via Twilio.
# Credentials are read from environment variables:
#   TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM
#
# In development the message is logged instead of sent (unless credentials are present).
class SmsService
  def self.send(to:, body:)
    new(to: to, body: body).deliver
  end

  def initialize(to:, body:)
    @to   = to
    @body = body
  end

  def deliver
    if credentials_present?
      client.messages.create(from: from_number, to: @to, body: @body)
    else
      Rails.logger.info("[SMS] To: #{@to} | Body: #{@body}")
    end
  rescue Twilio::REST::TwilioError => e
    Rails.logger.error("[SMS] Failed to send to #{@to}: #{e.message}")
  end

  private

  def client
    @client ||= Twilio::REST::Client.new(
      ENV.fetch("TWILIO_ACCOUNT_SID"),
      ENV.fetch("TWILIO_AUTH_TOKEN")
    )
  end

  def from_number
    ENV.fetch("TWILIO_FROM")
  end

  def credentials_present?
    ENV["TWILIO_ACCOUNT_SID"].present? &&
      ENV["TWILIO_AUTH_TOKEN"].present? &&
      ENV["TWILIO_FROM"].present?
  end
end
