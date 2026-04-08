class ServicesController < ApplicationController
  before_action :authenticate_staff!
  before_action :set_service, only: %i[show edit update destroy]

  def index
    @services = Service.order(:name)
  end

  def new
    @service = Service.new(duration_minutes: 30, active: true)
  end

  def create
    @service = Service.new(service_params)
    @service.salon = current_salon

    if @service.save
      redirect_to services_path, notice: "Service \"#{@service.name}\" added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @service.update(service_params)
      redirect_to services_path, notice: "Service updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @service.visits.exists?
      redirect_to services_path, alert: "Cannot delete a service that has visits. Deactivate it instead."
    else
      @service.destroy
      redirect_to services_path, notice: "Service removed."
    end
  end

  private

  def set_service
    @service = Service.find(params[:id])
  end

  def service_params
    params.require(:service).permit(:name, :base_price, :duration_minutes, :active)
  end
end
