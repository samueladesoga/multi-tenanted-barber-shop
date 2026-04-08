class AppointmentMailer < ApplicationMailer
  def booked(appointment)
    @appointment = appointment
    @salon       = appointment.salon
    @customer    = appointment.customer
    mail(
      to:      @customer.email,
      subject: "Appointment booked at #{@salon.name}"
    )
  end

  def confirmed(appointment)
    @appointment = appointment
    @salon       = appointment.salon
    @customer    = appointment.customer
    mail(
      to:      @customer.email,
      subject: "Your appointment at #{@salon.name} is confirmed"
    )
  end

  def cancelled(appointment)
    @appointment = appointment
    @salon       = appointment.salon
    @customer    = appointment.customer
    mail(
      to:      @customer.email,
      subject: "Appointment cancelled — #{@salon.name}"
    )
  end

  def reminder(appointment)
    @appointment = appointment
    @salon       = appointment.salon
    @customer    = appointment.customer
    mail(
      to:      @customer.email,
      subject: "Reminder: Your appointment tomorrow at #{@salon.name}"
    )
  end
end
