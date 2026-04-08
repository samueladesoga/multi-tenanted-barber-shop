require "test_helper"

class VisitsTest < ActionDispatch::IntegrationTest
  setup do
    host! "demo.example.com"
    sign_in staffs(:owner)
  end

  test "GET /visits lists recent visits" do
    get visits_path
    assert_response :success
  end

  test "GET /visits/new renders the form" do
    get new_visit_path
    assert_response :success
  end

  test "GET /visits/new with customer_id pre-fills the customer" do
    get new_visit_path, params: { customer_id: customers(:regular).id }
    assert_response :success
    assert_select "body", /Regular Customer/
  end

  test "GET /visits/new with phone param finds customer" do
    get new_visit_path, params: { phone: "07700900001" }
    assert_response :success
    assert_select "body", /Regular Customer/
  end

  test "GET /visits/new with name param finds matching customers" do
    get new_visit_path, params: { name: "near" }
    assert_response :success
    assert_select "body", /Near Milestone/
  end

  test "POST /visits creates a visit and redirects to the customer" do
    customer = customers(:regular)

    assert_difference "Visit.count", +1 do
      post visits_path, params: {
        visit: {
          customer_id:   customer.id,
          service_id:    services(:haircut).id,
          price_charged: 20.00
        }
      }
    end

    assert_redirected_to customer_path(customer)
    assert_match /Visit logged/, flash[:notice]
  end

  test "POST /visits at a loyalty milestone marks visit free and shows milestone notice" do
    customer = customers(:near_milestone)   # visits_count: 4, threshold: 5

    assert_difference "Visit.count", +1 do
      post visits_path, params: {
        visit: {
          customer_id:   customer.id,
          service_id:    services(:haircut).id,
          price_charged: 20.00
        }
      }
    end

    free_visit = Visit.order(:created_at).last
    assert free_visit.is_free
    assert_equal 0, free_visit.price_charged
    assert_match /Loyalty milestone/, flash[:notice]
  end

  test "GET /scan/:qr_token redirects to the new visit form" do
    get scan_qr_path(qr_token: customers(:regular).qr_token)
    assert_redirected_to new_visit_path(customer_id: customers(:regular).id)
  end

  test "GET /visits/:id shows the visit details" do
    get visit_path(visits(:regular_haircut))
    assert_response :success
  end
end
