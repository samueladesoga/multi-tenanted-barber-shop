require "test_helper"

class SalonTest < ActiveSupport::TestCase
  setup do
    @salon = salons(:demo)
  end

  # -- available_slots ---------------------------------------------------------

  test "available_slots returns time slots for an open weekday" do
    with_tenant(@salon) do
      # Find the next weekday (Mon–Fri) so working hours say open
      date = next_open_weekday
      slots = @salon.available_slots(date: date, duration_minutes: 30)

      assert slots.any?, "expected at least one slot for an open weekday"
      assert slots.all? { |s| s.is_a?(Time) }
    end
  end

  test "available_slots returns empty array for a closed day" do
    with_tenant(@salon) do
      # Mark Sunday as closed, then check slots
      sun = working_hours(:sunday)
      sun.update!(is_closed: true)

      date = next_day_of_week(0)   # next Sunday (wday 0 → day_of_week 6)
      slots = @salon.available_slots(date: date, duration_minutes: 30)
      assert_empty slots
    end
  end

  test "available_slots respects the working hours window" do
    with_tenant(@salon) do
      date  = next_open_weekday
      slots = @salon.available_slots(date: date, duration_minutes: 30)

      # All slots must start at or after opening time and before closing time
      opens_at  = working_hours(:monday).opens_at
      closes_at = working_hours(:monday).closes_at

      slots.each do |slot|
        slot_time = slot.strftime("%H:%M")
        assert slot_time >= opens_at.strftime("%H:%M"),  "slot #{slot_time} is before opening"
        assert slot_time <  closes_at.strftime("%H:%M"), "slot #{slot_time} is at or after closing"
      end
    end
  end

  test "available_slots excludes past times on today" do
    with_tenant(@salon) do
      slots = @salon.available_slots(date: Date.today, duration_minutes: 30)
      # All returned slots must be in the future (past slots are filtered out)
      slots.each { |slot| assert slot > Time.current, "slot #{slot} is in the past" }
      # Whether any slots exist depends on the time of day — just assert the method returns an Array
      assert_kind_of Array, slots
    end
  end

  # -- working_hour_for --------------------------------------------------------

  test "working_hour_for returns the record for the given day index" do
    with_tenant(@salon) do
      wh = @salon.working_hour_for(0)   # Monday
      assert_not_nil wh
      assert_equal "monday", wh.day_of_week
    end
  end

  test "working_hour_for returns nil for a day with no record" do
    with_tenant(@salon) do
      # Create a fresh salon with no working hours
      fresh = Salon.create!(
        name: "Fresh Salon", subdomain: "fresh",
        owner_name: "Owner", owner_email: "owner@fresh.com",
        loyalty_threshold: 5, chair_count: 1
      )
      assert_nil fresh.working_hour_for(0)
    end
  end

  # -- seed_working_hours! -----------------------------------------------------

  test "seed_working_hours! creates 7 records" do
    fresh = Salon.create!(
      name: "Seed Test", subdomain: "seedtest",
      owner_name: "Owner", owner_email: "owner@seed.com",
      loyalty_threshold: 5, chair_count: 1
    )
    ActsAsTenant.with_tenant(fresh) { fresh.seed_working_hours! }

    assert_equal 7, fresh.working_hours.count
  end

  test "seed_working_hours! defaults all 7 days to open" do
    fresh = Salon.create!(
      name: "Seed Test 2", subdomain: "seedtest2",
      owner_name: "Owner", owner_email: "owner2@seed.com",
      loyalty_threshold: 5, chair_count: 1
    )
    ActsAsTenant.with_tenant(fresh) { fresh.seed_working_hours! }

    assert fresh.working_hours.none?(&:is_closed), "expected all days to default to open"
  end

  # -- update_working_hours ----------------------------------------------------

  test "update_working_hours saves new open/close times" do
    with_tenant(@salon) do
      mon = working_hours(:monday)
      result = @salon.update_working_hours(
        mon.id.to_s => { is_closed: "0", opens_at: "08:00", closes_at: "17:00" }
      )

      assert result
      assert_equal "08:00", mon.reload.opens_at.strftime("%H:%M")
      assert_equal "17:00", mon.reload.closes_at.strftime("%H:%M")
    end
  end

  test "update_working_hours can mark a day as closed" do
    with_tenant(@salon) do
      mon = working_hours(:monday)
      @salon.update_working_hours(mon.id.to_s => { is_closed: "1" })
      assert mon.reload.is_closed
    end
  end

  private
    # Returns the next date (from tomorrow) that is Mon–Fri
    def next_open_weekday
      date = Date.tomorrow
      date = date.next_day while date.wday == 0 || date.wday == 6
      date
    end

    # Returns the next date with the given Ruby wday (0=Sun … 6=Sat)
    def next_day_of_week(wday)
      date = Date.tomorrow
      date = date.next_day until date.wday == wday
      date
    end
end
