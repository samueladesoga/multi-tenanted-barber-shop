class SettingsController < ApplicationController
  include OwnerRequired
  before_action :authenticate_staff!

  def edit
    @salon = Current.salon
  end

  def update
    @salon = Current.salon

    if @salon.update(salon_params)
      redirect_to edit_settings_path, notice: "Settings saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def salon_params
      params.require(:salon).permit(:name, :loyalty_threshold, :chair_count, :currency)
    end
end
