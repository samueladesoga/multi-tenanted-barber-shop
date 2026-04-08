require "test_helper"

class CustomersTest < ActionDispatch::IntegrationTest
  setup do
    host! "demo.example.com"
    sign_in staffs(:owner)
  end

  test "GET /customers lists all customers" do
    get customers_path
    assert_response :success
    assert_select "body", /Regular Customer/
  end

  test "GET /customers with search param filters by name" do
    get customers_path, params: { q: "regular" }
    assert_response :success
    assert_select "body", /Regular Customer/
  end

  test "GET /customers with JSON format returns customer data" do
    get customers_path(format: :json), params: { q: "Regular" }
    assert_response :success
    data = JSON.parse(response.body)
    assert data.any? { |c| c["name"] == "Regular Customer" }
  end

  test "GET /customers/new renders the form" do
    get new_customer_path
    assert_response :success
  end

  test "POST /customers creates a customer and redirects to QR code" do
    assert_difference "Customer.count", +1 do
      post customers_path, params: {
        customer: {
          name:         "Fresh Customer",
          phone_number: "07711000001",
          email:        "fresh@example.com"
        }
      }
    end

    new_customer = Customer.order(:created_at).last
    assert_redirected_to qr_code_customer_path(new_customer)
    assert_not_nil new_customer.qr_token
  end

  test "GET /customers/:id shows the customer's profile and recent visits" do
    get customer_path(customers(:regular))
    assert_response :success
    assert_select "body", /Regular Customer/
  end

  test "GET /customers/:id/qr_code renders the QR card" do
    get qr_code_customer_path(customers(:regular))
    assert_response :success
    assert_select "body", /Regular Customer/
  end

  test "PATCH /customers/:id updates the customer" do
    patch customer_path(customers(:regular)), params: {
      customer: { name: "Updated Name" }
    }
    assert_redirected_to customer_path(customers(:regular))
    assert_equal "Updated Name", customers(:regular).reload.name
  end

  test "DELETE /customers/:id removes the customer" do
    customer = customers(:regular)
    assert_difference "Customer.count", -1 do
      delete customer_path(customer)
    end
    assert_redirected_to customers_path
  end
end
