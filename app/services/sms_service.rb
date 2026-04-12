# Sends WhatsApp messages via the Meta WhatsApp Cloud API.
# Credentials are read from environment variables:
#   WHATSAPP_TOKEN           — permanent access token from Meta developer console
#   WHATSAPP_PHONE_NUMBER_ID — the numeric ID of your registered WhatsApp number
#
# In development the message is logged instead of sent (unless credentials are present).
require "net/http"
require "json"

class SmsService
  GRAPH_API_VERSION = "v19.0"

  def self.send(to:, body:)
    new(to: to, body: body).deliver
  end

  def initialize(to:, body:)
    @to   = to
    @body = body
  end

  def deliver
    if credentials_present?
      send_whatsapp
    else
      Rails.logger.info("[WhatsApp] To: #{@to} | Body: #{@body}")
    end
  end

  private

  def send_whatsapp
    uri = URI("https://graph.facebook.com/#{GRAPH_API_VERSION}/#{phone_number_id}/messages")
    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{token}"
    req["Content-Type"]  = "application/json"
    req.body = {
      messaging_product: "whatsapp",
      to:                @to,
      type:              "text",
      text:              { body: @body }
    }.to_json

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      res = http.request(req)
      unless res.is_a?(Net::HTTPSuccess)
        Rails.logger.error("[WhatsApp] Failed to send to #{@to}: #{res.body}")
      end
    end
  rescue => e
    Rails.logger.error("[WhatsApp] Error sending to #{@to}: #{e.message}")
  end

  def credentials_present?
    ENV["WHATSAPP_TOKEN"].present? && ENV["WHATSAPP_PHONE_NUMBER_ID"].present?
  end

  def token           = ENV.fetch("WHATSAPP_TOKEN")
  def phone_number_id = ENV.fetch("WHATSAPP_PHONE_NUMBER_ID")
end
