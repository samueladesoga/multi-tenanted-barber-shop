class AppointmentsController < ApplicationController
  before_action :authenticate_staff!
  before_action :set_appointment, only: %i[ show edit update destroy ]

  def index
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @appointments  = Appointment.includes(:customer, :service, :staff)
                                .for_date(@date)
                                .order(:scheduled_at)
    @pending_count = Appointment.upcoming.where(status: :pending).count
  end

  def show
  end

  def new
    @appointment = Appointment.new(scheduled_at: Time.current.tomorrow.change(hour: 9, min: 0))
    load_form_data
  end

  def create
    @appointment = Appointment.new(appointment_params)
    @appointment.salon     = Current.salon
    @appointment.booked_by = :staff_member
    @appointment.status    = :confirmed

    if @appointment.save
      AppointmentNotifier.notify(@appointment, :booked)
      redirect_to appointments_path, notice: "Appointment booked for #{@appointment.customer.name}."
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_data
  end

  def update
    if @appointment.update(appointment_params)
      redirect_to appointments_path, notice: "Appointment updated."
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @appointment.cancel!
    redirect_to appointments_path, notice: "Appointment cancelled."
  end

  # AJAX — available slots for a given date + service
  def slots
    date     = Date.parse(params[:date]) rescue Date.today
    duration = Service.find_by(id: params[:service_id])&.duration_minutes || 30
    slots    = Current.salon.available_slots(
      date:                  date,
      duration_minutes:      duration,
      exclude_appointment_id: params[:exclude_id]
    )

    render json: slots.map { |s| { value: s.iso8601, label: s.strftime("%H:%M") } }
  end

  private
    def set_appointment
      @appointment = Appointment.find(params[:id])
    end

    def load_form_data
      date     = @appointment.scheduled_at&.to_date || Date.today
      duration = Service.find_by(id: @appointment.service_id)&.duration_minutes ||
                 @appointment.service&.duration_minutes || 30
      @slots   = Current.salon.available_slots(
        date:                  date,
        duration_minutes:      duration,
        exclude_appointment_id: @appointment.id
      )
      @services = Service.active.order(:name)
      @staffs   = Current.salon.staffs.order(:name)
    end

    def appointment_params
      params.require(:appointment).permit(:customer_id, :service_id, :staff_id,
                                          :scheduled_at, :notes)
    end
end
