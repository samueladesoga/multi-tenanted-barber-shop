class RegistrationsController < ApplicationController
  def new
    @salon = Salon.new
    @staff = Staff.new
  end

  def create
    @salon = Salon.new(salon_params)

    # Build owner staff record alongside the salon
    @staff = @salon.staffs.build(
      name:                  @salon.owner_name,
      email:                 @salon.owner_email,
      password:              staff_params[:password],
      password_confirmation: staff_params[:password_confirmation],
      role:                  :owner
    )

    if @salon.save
      ActsAsTenant.with_tenant(@salon) { @salon.seed_working_hours! }
      sign_in(@staff)
      redirect_to "http://#{@salon.subdomain}.#{request.domain}/working_hours",
                  notice: "Welcome! Set your working hours to complete setup."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def salon_params
      params.require(:salon).permit(:name, :subdomain, :owner_name, :owner_email,
                                    :loyalty_threshold, :chair_count)
    end

    def staff_params
      params.require(:salon).permit(:password, :password_confirmation)
    end
end
