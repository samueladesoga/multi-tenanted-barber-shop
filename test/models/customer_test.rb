require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  setup do
    @salon    = salons(:demo)
    @customer = customers(:regular)
    @near     = customers(:near_milestone)
  end

  # -- Loyalty -----------------------------------------------------------------

  test "visits_until_free returns full threshold for a brand-new customer" do
    with_tenant(@salon) do
      assert_equal 5, @customer.visits_until_free
    end
  end

  test "visits_until_free returns 1 when one visit away" do
    with_tenant(@salon) do
      assert_equal 1, @near.visits_until_free
    end
  end

  test "next_visit_free? is true when one visit remains" do
    with_tenant(@salon) do
      assert @near.next_visit_free?
    end
  end

  test "next_visit_free? is false for a regular customer" do
    with_tenant(@salon) do
      assert_not @customer.next_visit_free?
    end
  end

  test "loyalty_milestone? is true when visits_count is an exact multiple of threshold" do
    with_tenant(@salon) do
      customer = customers(:veteran)   # visits_count: 10, threshold: 5
      assert customer.loyalty_milestone?
    end
  end

  test "loyalty_milestone? is false for visits_count of zero" do
    with_tenant(@salon) do
      assert_not @customer.loyalty_milestone?
    end
  end

  # -- QR token ----------------------------------------------------------------

  test "qr_token is generated on create" do
    with_tenant(@salon) do
      customer = Customer.create!(name: "New Person", phone_number: "07700999999", salon: @salon)
      assert_not_nil customer.qr_token
      assert customer.qr_token.length > 10
    end
  end

  test "each customer gets a unique qr_token" do
    with_tenant(@salon) do
      a = Customer.create!(name: "Person A", phone_number: "07700111111", salon: @salon)
      b = Customer.create!(name: "Person B", phone_number: "07700222222", salon: @salon)
      assert_not_equal a.qr_token, b.qr_token
    end
  end

  # -- Search scopes -----------------------------------------------------------

  test "search scope finds customer by name" do
    with_tenant(@salon) do
      results = Customer.search("Regular")
      assert_includes results, @customer
    end
  end

  test "search scope is case-insensitive" do
    with_tenant(@salon) do
      results = Customer.search("regular")
      assert_includes results, @customer
    end
  end

  test "search scope finds customer by phone number" do
    with_tenant(@salon) do
      results = Customer.search("07700900001")
      assert_includes results, @customer
    end
  end

  test "by_phone scope finds by partial phone number" do
    with_tenant(@salon) do
      results = Customer.by_phone("900001")
      assert_includes results, @customer
    end
  end

  test "by_name scope finds by partial name" do
    with_tenant(@salon) do
      results = Customer.by_name("near")
      assert_includes results, @near
    end
  end

  test "near_loyalty_milestone scope returns customers one visit away" do
    with_tenant(@salon) do
      results = Customer.near_loyalty_milestone(@salon.loyalty_threshold)
      assert_includes results, @near
      assert_not_includes results, @customer
    end
  end
end
