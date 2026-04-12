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
    if current_salon.update_working_hours(working_hours_params)
      redirect_to working_hours_path, notice: "Working hours updated."
    else
      redirect_to working_hours_path, alert: "Could not save working hours. Please check your entries."
    end
  end

  private
    def working_hours_params
      wh_ids = current_salon.working_hours.pluck(:id).map(&:to_s)
      wh_ids.each_with_object({}) do |id, result|
        next unless params[:working_hours]&.key?(id)
        result[id] = params.require(:working_hours).require(id)
                           .permit(:opens_at, :closes_at, :is_closed).to_h
      end
    end
end
