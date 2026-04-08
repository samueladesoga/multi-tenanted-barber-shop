class Appointments::CompletionsController < ApplicationController
  before_action :authenticate_staff!

  def create
    appointment = Appointment.find(params[:appointment_id])
    appointment.complete!
    redirect_to new_visit_path(customer_id: appointment.customer_id, service_id: appointment.service_id),
                notice: "Appointment complete — log the visit below."
  end
end
