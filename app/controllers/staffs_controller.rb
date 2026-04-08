class StaffsController < ApplicationController
  include OwnerRequired
  before_action :authenticate_staff!
  before_action :set_staff, only: %i[ edit update destroy ]

  def index
    @staffs = Current.salon.staffs.order(:name)
  end

  def new
    @staff = Staff.new(role: :staff)
  end

  def create
    @staff = Staff.new(staff_params)
    @staff.salon = Current.salon

    if @staff.save
      redirect_to staffs_path, notice: "#{@staff.name} added to the team."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @staff.update(update_params)
      redirect_to staffs_path, notice: "#{@staff.name} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @staff == Current.staff
      redirect_to staffs_path, alert: "You cannot remove yourself."
    else
      @staff.destroy!
      redirect_to staffs_path, notice: "Staff member removed."
    end
  end

  private
    def set_staff
      @staff = Current.salon.staffs.find(params[:id])
    end

    def staff_params
      params.require(:staff).permit(:name, :email, :role, :password, :password_confirmation)
    end

    def update_params
      # Only include password if one was provided
      permitted = params.require(:staff).permit(:name, :email, :role, :password, :password_confirmation)
      permitted.reject { |k, v| k.to_s.include?("password") && v.blank? }
    end
end
