require "test_helper"

# Public customer self-booking — no staff authentication required.
class BookingsTest < ActionDispatch::IntegrationTest
  setup do
    host! "demo.example.com"
    # Deliberately NOT signing in — bookings are public
  end

  test "GET /book renders the public booking page" do
    get new_booking_path
    assert_response :success
  end

  test "GET /book with phone param finds an existing customer" do
    get new_booking_path, params: { phone: "07700900001" }
    assert_response :success
    assert_select "body", /Regular Customer/
  end

  test "GET /book with name param lists matching customers" do
    get new_booking_path, params: { name: "near" }
    assert_response :success
    assert_select "body", /Near Milestone/
  end

  test "GET /book/slots returns available slots as JSON for an open weekday" do
    # Find the next Mon–Fri so working hours say open
    date = Date.tomorrow
    date = date.next_day while date.wday == 0 || date.wday == 6

    get booking_slots_path, params: {
      date:       date.iso8601,
      service_id: services(:haircut).id
    }, as: :json

    assert_response :success
    slots = JSON.parse(response.body)
    assert slots.is_a?(Array)
    assert slots.any?, "expected slots for an open weekday (#{date.strftime('%A')})"
  end

  test "POST /book creates an appointment for an existing customer" do
    customer  = customers(:regular)
    service   = services(:haircut)
    weekday   = (Date.today + 8).tap { |d| d = d.next_day while d.wday == 0 || d.wday == 6 }
    scheduled = weekday.to_time.change(hour: 10, min: 0)

    assert_difference "Appointment.count", +1 do
      post bookings_path, params: {
        booking: {
          customer_id:  customer.id,
          service_id:   service.id,
          scheduled_at: scheduled.iso8601
        }
      }
    end

    appt = Appointment.order(:created_at).last
    assert appt.pending?,       "self-booked appointments start as pending"
    assert appt.customer_self?, "booked_by should be customer_self"
    assert_equal customer, appt.customer
    assert_redirected_to new_booking_path
    assert_match /appointment is booked/, flash[:notice]
  end

  test "POST /book finds or creates customer by phone number" do
    service   = services(:beard_trim)
    weekday   = (Date.today + 9).tap { |d| d = d.next_day while d.wday == 0 || d.wday == 6 }
    scheduled = weekday.to_time.change(hour: 11, min: 0)

    assert_difference "Appointment.count", +1 do
      post bookings_path, params: {
        booking: {
          phone_number: "07712345678",
          name:         "Walk-in Customer",
          service_id:   service.id,
          scheduled_at: scheduled.iso8601
        }
      }
    end

    assert Customer.find_by(phone_number: "07712345678").present?
  end
end
