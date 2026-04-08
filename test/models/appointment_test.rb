require "test_helper"

class AppointmentTest < ActiveSupport::TestCase
  setup do
    @salon       = salons(:demo)
    @pending     = appointments(:pending_morning)
    @confirmed   = appointments(:confirmed_afternoon)
  end

  # -- State transitions -------------------------------------------------------

  test "confirm! changes status to confirmed" do
    with_tenant(@salon) do
      @pending.confirm!
      assert @pending.reload.confirmed?
    end
  end

  test "cancel! changes status to cancelled" do
    with_tenant(@salon) do
      @confirmed.cancel!
      assert @confirmed.reload.cancelled?
    end
  end

  test "complete! changes status to completed" do
    with_tenant(@salon) do
      @confirmed.complete!
      assert @confirmed.reload.completed?
    end
  end

  # -- Duration and end time ---------------------------------------------------

  test "duration_minutes falls back to 30 when no service is attached" do
    with_tenant(@salon) do
      appt = Appointment.new
      assert_equal 30, appt.duration_minutes
    end
  end

  test "duration_minutes uses the service duration when present" do
    with_tenant(@salon) do
      assert_equal services(:haircut).duration_minutes, @pending.duration_minutes
    end
  end

  test "ends_at is scheduled_at plus duration" do
    with_tenant(@salon) do
      expected = @pending.scheduled_at + @pending.duration_minutes.minutes
      assert_equal expected, @pending.ends_at
    end
  end

  # -- convertible_to_visit? ---------------------------------------------------

  test "convertible_to_visit? is true for confirmed appointments" do
    with_tenant(@salon) do
      assert @confirmed.convertible_to_visit?
    end
  end

  test "convertible_to_visit? is false for pending appointments" do
    with_tenant(@salon) do
      assert_not @pending.convertible_to_visit?
    end
  end

  # -- Scopes ------------------------------------------------------------------

  test "upcoming scope includes future pending appointments" do
    with_tenant(@salon) do
      assert_includes Appointment.upcoming, @pending
    end
  end

  test "for_date scope returns appointments on the given date" do
    with_tenant(@salon) do
      date   = @pending.scheduled_at.to_date
      result = Appointment.for_date(date)
      assert_includes result, @pending
    end
  end

  test "active scope returns pending and confirmed appointments" do
    with_tenant(@salon) do
      assert_includes Appointment.active, @pending
      assert_includes Appointment.active, @confirmed
    end
  end
end
