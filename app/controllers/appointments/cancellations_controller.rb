class Appointments::CancellationsController < ApplicationController
  before_action :authenticate_staff!

  def create
    appointment = Appointment.find(params[:appointment_id])
    appointment.cancel!
    redirect_back fallback_location: appointments_path, notice: "Appointment cancelled."
  end
end
