# Orchestrates email and SMS notifications for appointment events.
# Usage: AppointmentNotifier.notify(appointment, :booked)
class AppointmentNotifier
  EVENTS = %i[booked confirmed cancelled reminder].freeze

  def self.notify(appointment, event)
    raise ArgumentError, "Unknown event: #{event}" unless EVENTS.include?(event.to_sym)
    new(appointment, event.to_sym).deliver
  end

  def initialize(appointment, event)
    @appointment = appointment
    @event       = event
    @customer    = appointment.customer
    @salon       = appointment.salon
  end

  def deliver
    send_email
    send_sms
  end

  private

  def send_email
    return unless @customer.email.present?
    AppointmentMailer.send(@event, @appointment).deliver_later
  end

  def send_sms
    return unless @customer.phone_number.present?
    SmsService.send(to: @customer.phone_number, body: sms_body)
  end

  def sms_body
    time = @appointment.scheduled_at.strftime("%a %d %b at %H:%M")
    case @event
    when :booked
      "Hi #{@customer.name}, your appointment at #{@salon.name} on #{time} has been received. We'll confirm shortly."
    when :confirmed
      "Hi #{@customer.name}, your appointment at #{@salon.name} on #{time} is confirmed. See you then!"
    when :cancelled
      "Hi #{@customer.name}, your appointment at #{@salon.name} on #{time} has been cancelled. Please rebook at your convenience."
    when :reminder
      "Reminder: You have an appointment at #{@salon.name} tomorrow, #{time}. See you there!"
    end
  end
end
