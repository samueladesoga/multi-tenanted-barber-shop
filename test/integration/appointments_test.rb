require "test_helper"

class AppointmentsTest < ActionDispatch::IntegrationTest
  setup do
    host! "demo.example.com"
    sign_in staffs(:owner)
  end

  test "GET /appointments lists appointments for today" do
    get appointments_path
    assert_response :success
  end

  test "GET /appointments/new renders the booking form" do
    get new_appointment_path
    assert_response :success
  end

  test "POST /appointments creates a confirmed appointment" do
    customer  = customers(:regular)
    service   = services(:haircut)
    weekday   = (Date.today + 8).tap { |d| d = d.next_day while d.wday == 0 || d.wday == 6 }
    scheduled = weekday.to_time.change(hour: 11, min: 0)

    assert_difference "Appointment.count", +1 do
      post appointments_path, params: {
        appointment: {
          customer_id:  customer.id,
          service_id:   service.id,
          staff_id:     staffs(:barber).id,
          scheduled_at: scheduled.iso8601
        }
      }
    end

    appt = Appointment.order(:created_at).last
    assert appt.confirmed?, "newly booked appointment should be confirmed"
    assert appt.staff_member?, "booked_by should be staff_member"
    assert_redirected_to appointments_path
  end

  test "GET /appointments/:id shows appointment details" do
    get appointment_path(appointments(:pending_morning))
    assert_response :success
  end

  test "POST /appointments/:id/confirmation confirms a pending appointment" do
    appt = appointments(:pending_morning)
    assert appt.pending?

    post appointment_confirmation_path(appt)

    assert appt.reload.confirmed?
    assert_redirected_to appointments_path
    assert_match /confirmed/, flash[:notice]
  end

  test "POST /appointments/:id/cancellation cancels an appointment" do
    appt = appointments(:confirmed_afternoon)

    post appointment_cancellation_path(appt)

    assert appt.reload.cancelled?
    assert_redirected_to appointments_path
    assert_match /cancelled/, flash[:notice]
  end

  test "POST /appointments/:id/completion completes an appointment and redirects to new visit" do
    appt = appointments(:confirmed_afternoon)

    post appointment_completion_path(appt)

    assert appt.reload.completed?
    assert_redirected_to new_visit_path(
      customer_id: appt.customer_id,
      service_id:  appt.service_id
    )
  end

  test "PATCH /appointments/:id updates the appointment" do
    appt      = appointments(:pending_morning)
    weekday   = (Date.today + 9).tap { |d| d = d.next_day while d.wday == 0 || d.wday == 6 }
    new_time  = weekday.to_time.change(hour: 9, min: 30)

    patch appointment_path(appt), params: {
      appointment: { scheduled_at: new_time.iso8601 }
    }

    assert_redirected_to appointments_path
    assert_in_delta new_time, appt.reload.scheduled_at, 1.second
  end

  test "GET /appointments/slots returns JSON slot list for an open weekday" do
    date = Date.tomorrow
    date = date.next_day while date.wday == 0 || date.wday == 6

    get slots_appointments_path, params: {
      date:       date.iso8601,
      service_id: services(:haircut).id
    }, as: :json

    assert_response :success
    slots = JSON.parse(response.body)
    assert slots.is_a?(Array)
    assert slots.all? { |s| s.key?("value") && s.key?("label") }
  end
end
