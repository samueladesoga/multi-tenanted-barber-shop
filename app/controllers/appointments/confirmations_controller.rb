class Appointments::ConfirmationsController < ApplicationController
  before_action :authenticate_staff!

  def create
    appointment = Appointment.find(params[:appointment_id])
    appointment.confirm!
    redirect_back fallback_location: appointments_path, notice: "Appointment confirmed."
  end
end
