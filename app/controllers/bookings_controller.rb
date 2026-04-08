# Public booking controller — no staff auth required.
# Customers book appointments using only their phone number or name.
class BookingsController < ApplicationController
  def new
    @services = Service.active.order(:name)
    @salon    = current_salon

    if params[:customer_id].present?
      @customer = Customer.find_by(id: params[:customer_id])
    elsif params[:phone].present?
      found = Customer.by_phone(params[:phone]).first
      if found
        @customer = found     # jump straight to the booking form
      else
        @not_found = true     # show the self-registration form
      end
    elsif params[:name].present?
      @found_customers = Customer.by_name(params[:name]).limit(8)
    end
  end

  def slots
    date     = Date.parse(params[:date]) rescue Date.today
    duration = Service.find_by(id: params[:service_id])&.duration_minutes || 30
    slots    = current_salon.available_slots(date: date, duration_minutes: duration)

    render json: slots.map { |s| { value: s.iso8601, label: s.strftime("%H:%M") } }
  end

  def create
    @salon    = current_salon
    @services = Service.active.order(:name)

    # Find or create a minimal customer record from phone number
    @customer = Customer.find_by(id: booking_params[:customer_id])

    if @customer.nil? && booking_params[:phone_number].present?
      @customer = Customer.find_or_initialize_by(phone_number: booking_params[:phone_number])
      @customer.name = booking_params[:name].presence || "Customer"
      @customer.salon = @salon
      @customer.save!
    end

    if @customer.nil?
      redirect_to new_booking_path, alert: "Could not find your details. Please try again."
      return
    end

    @appointment = Appointment.new(
      salon:        @salon,
      customer:     @customer,
      service_id:   booking_params[:service_id],
      scheduled_at: booking_params[:scheduled_at],
      notes:        booking_params[:notes],
      booked_by:    :customer_self,
      status:       :pending
    )

    if @appointment.save
      AppointmentNotifier.notify(@appointment, :booked)
      redirect_to new_booking_path,
                  notice: "Your appointment is booked for #{@appointment.scheduled_at.strftime('%A, %d %b at %H:%M')}. We'll send a confirmation shortly."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def booking_params
      params.require(:booking).permit(:customer_id, :phone_number, :name,
                                      :service_id, :scheduled_at, :notes)
    end
end
