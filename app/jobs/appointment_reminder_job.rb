class AppointmentReminderJob < ApplicationJob
  queue_as :default

  # Finds all confirmed/pending appointments scheduled for tomorrow and sends reminders.
  # Runs daily at 9am via Solid Queue recurring schedule (configured in config/recurring.yml).
  def perform
    tomorrow_start = Date.tomorrow.beginning_of_day
    tomorrow_end   = Date.tomorrow.end_of_day

    appointments = Appointment
      .includes(:customer, :service, :salon)
      .where(scheduled_at: tomorrow_start..tomorrow_end)
      .where(status: [ :pending, :confirmed ])

    appointments.each do |appointment|
      ActsAsTenant.with_tenant(appointment.salon) do
        AppointmentNotifier.notify(appointment, :reminder)
      end
    end

    Rails.logger.info("[AppointmentReminderJob] Sent #{appointments.count} reminder(s) for #{Date.tomorrow}")
  end
end
