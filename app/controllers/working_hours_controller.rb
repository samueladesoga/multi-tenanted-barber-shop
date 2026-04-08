class WorkingHoursController < ApplicationController
  include OwnerRequired
  before_action :authenticate_staff!

  def index
    @working_hours = WorkingHour::DAYS.map do |day|
      current_salon.working_hours.find_or_initialize_by(day_of_week: day)
    end
  end

  def edit
    @working_hour = WorkingHour.find(params[:id])
  end

  def update
    if current_salon.update_working_hours(params[:working_hours])
      redirect_to working_hours_path, notice: "Working hours updated."
    else
      redirect_to working_hours_path, alert: "Could not save working hours. Please check your entries."
    end
  end
end
