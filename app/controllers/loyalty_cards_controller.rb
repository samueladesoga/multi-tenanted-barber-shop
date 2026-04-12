class LoyaltyCardsController < ApplicationController
  def show
    @customer = Customer.find_by!(qr_token: params[:qr_token])
    @salon    = @customer.salon
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Loyalty card not found."
  end
end
