require "test_helper"

class VisitTest < ActiveSupport::TestCase
  setup do
    @salon    = salons(:demo)
    @service  = services(:haircut)
    @staff    = staffs(:barber)
  end

  # -- Loyalty discount callback -----------------------------------------------

  test "apply_loyalty_discount marks visit free at the milestone" do
    with_tenant(@salon) do
      # near_milestone customer has visits_count: 4, threshold is 5
      # next visit (the 5th) should be free
      customer = customers(:near_milestone)

      visit = Visit.create!(
        customer:      customer,
        service:       @service,
        staff:         @staff,
        salon:         @salon,
        price_charged: @service.base_price
      )

      assert visit.is_free, "visit should be marked free at loyalty milestone"
      assert_equal 0, visit.price_charged
    end
  end

  test "normal visit is not marked free when customer is not at milestone" do
    with_tenant(@salon) do
      customer = customers(:regular)   # visits_count: 0

      visit = Visit.create!(
        customer:      customer,
        service:       @service,
        staff:         @staff,
        salon:         @salon,
        price_charged: @service.base_price
      )

      assert_not visit.is_free
      assert_equal @service.base_price, visit.price_charged
    end
  end

  test "staff can manually override is_free without being overwritten by callback" do
    with_tenant(@salon) do
      customer = customers(:regular)   # not at milestone

      visit = Visit.create!(
        customer:      customer,
        service:       @service,
        staff:         @staff,
        salon:         @salon,
        price_charged: 0,
        is_free:       true
      )

      assert visit.is_free
    end
  end

  test "creating a visit increments the customer visits_count" do
    with_tenant(@salon) do
      customer = customers(:regular)
      assert_difference -> { customer.reload.visits_count }, +1 do
        Visit.create!(
          customer:      customer,
          service:       @service,
          staff:         @staff,
          salon:         @salon,
          price_charged: @service.base_price
        )
      end
    end
  end

  # -- discounted? and discount_amount -----------------------------------------

  test "discounted? is true when price_charged is below base_price" do
    with_tenant(@salon) do
      visit = visits(:discounted_haircut)
      assert visit.discounted?
    end
  end

  test "discounted? is false when full price is charged" do
    with_tenant(@salon) do
      visit = visits(:regular_haircut)
      assert_not visit.discounted?
    end
  end

  test "discount_amount is the difference between base_price and price_charged" do
    with_tenant(@salon) do
      visit = visits(:discounted_haircut)
      expected = services(:haircut).base_price - visit.price_charged
      assert_equal expected, visit.discount_amount
    end
  end

  # -- Scopes ------------------------------------------------------------------

  test "discounted scope returns only discounted visits" do
    with_tenant(@salon) do
      discounted = Visit.discounted
      assert_includes discounted, visits(:discounted_haircut)
      assert_not_includes discounted, visits(:regular_haircut)
    end
  end

  test "for_month scope returns visits in the given month" do
    with_tenant(@salon) do
      year  = Date.today.year
      month = Date.today.month
      visits = Visit.for_month(year, month)
      # monthly_rent expense is this month, regular_haircut is 1 week ago (this month)
      assert_includes visits, visits(:regular_haircut)
    end
  end
end
