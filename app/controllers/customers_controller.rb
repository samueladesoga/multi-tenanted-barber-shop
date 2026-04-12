class CustomersController < ApplicationController
  before_action :authenticate_staff!
  before_action :set_customer, only: %i[ show edit update destroy qr_code share_loyalty_card ]

  def index
    @customers = params[:q].present? ? Customer.search(params[:q]).order(:name) : Customer.order(:name)

    respond_to do |format|
      format.html
      format.json { render json: @customers.limit(10).map { |c| { id: c.id, name: c.name, phone_number: c.phone_number } } }
    end
  end

  def show
    @recent_visits = @customer.visits.includes(:service).order(visited_at: :desc).limit(10)
  end

  def new
    @customer = Customer.new
  end

  def create
    @customer = Customer.new(customer_params)
    @customer.salon = current_salon

    if @customer.save
      redirect_to qr_code_customer_path(@customer),
                  notice: "#{@customer.name} registered! Here is their QR code."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_to @customer, notice: "Customer updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer.destroy
    redirect_to customers_path, notice: "Customer removed."
  end

  def qr_code
    # Rendered in view — no extra logic needed
  end

  def share_loyalty_card
    if @customer.email.blank?
      redirect_to qr_code_customer_path(@customer), alert: "This customer has no email address on file."
      return
    end

    CustomerMailer.loyalty_card(@customer).deliver_later
    redirect_to qr_code_customer_path(@customer), notice: "Loyalty card sent to #{@customer.email}."
  end

  private
    def set_customer
      @customer = Customer.find(params[:id])
    end

    def customer_params
      params.require(:customer).permit(:name, :phone_number, :email, :area, :state)
    end
end
