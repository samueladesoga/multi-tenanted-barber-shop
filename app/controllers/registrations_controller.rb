class RegistrationsController < ApplicationController
  def new
    @salon = Salon.new
    @staff = Staff.new
  end

  def create
    @salon = Salon.new(salon_params)
    @staff = @salon.build_owner(**staff_params.to_h.symbolize_keys)

    if @salon.save
      ActsAsTenant.with_tenant(@salon) { @salon.seed_working_hours! }
      sign_in(@staff)
      redirect_to request.base_url.sub("://", "://#{@salon.subdomain}.") + "/working_hours",
                  notice: "Welcome! Set your working hours to complete setup.",
                  allow_other_host: true
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
