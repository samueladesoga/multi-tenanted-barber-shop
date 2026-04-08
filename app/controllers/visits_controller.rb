class VisitsController < ApplicationController
  before_action :authenticate_staff!, except: :scan

  def index
    @visits = Visit.includes(:customer, :service, :staff).order(visited_at: :desc).limit(50)
  end

  def scan
    # Public endpoint — resolves customer from QR token and redirects to check-in
    @customer = Customer.find_by!(qr_token: params[:qr_token])
    redirect_to new_visit_path(customer_id: @customer.id)
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: "QR code not recognised."
  end

  def new
    @visit    = Visit.new
    @services = Service.active.order(:name)

    # Pre-fill customer if supplied (from QR scan, direct link, or search)
    if params[:customer_id].present?
      @customer = Customer.find_by(id: params[:customer_id])
    elsif params[:phone].present?
      @customer = Customer.by_phone(params[:phone]).first
    elsif params[:name].present?
      @customers = Customer.by_name(params[:name]).limit(10)
    end
  end

  def create
    @customer = Customer.find(params[:visit][:customer_id])
    @visit    = Visit.new(visit_params)
    @visit.salon = current_salon
    @visit.staff = current_staff

    if @visit.save
      @customer.reload
      loyalty_msg = @customer.loyalty_milestone? ? " Loyalty milestone reached — this visit is FREE!" : ""
      redirect_to customer_path(@customer),
                  notice: "Visit logged for #{@customer.name}.#{loyalty_msg}"
    else
      @services = Service.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @visit = Visit.includes(:customer, :service, :staff).find(params[:id])
  end

  private
    def visit_params
      params.require(:visit).permit(:customer_id, :service_id, :price_charged,
                                    :discount_reason, :is_free, :visited_at)
    end
end
