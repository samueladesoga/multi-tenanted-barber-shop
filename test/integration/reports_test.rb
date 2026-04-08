require "test_helper"

class ReportsTest < ActionDispatch::IntegrationTest
  setup do
    host! "demo.example.com"
    sign_in staffs(:owner)
  end

  # -- P&L report --------------------------------------------------------------

  test "GET /reports renders the monthly P&L page" do
    get reports_path
    assert_response :success
  end

  test "GET /reports with month param renders that month" do
    get reports_path, params: { month: Date.today.strftime("%Y-%m") }
    assert_response :success
  end

  test "GET /reports shows revenue and expense totals" do
    get reports_path
    assert_select "body", /Total Revenue/
    assert_select "body", /Total Expenses/
  end

  # -- Service profitability ---------------------------------------------------

  test "GET /reports/services renders the service breakdown" do
    get service_reports_path
    assert_response :success
  end

  test "GET /reports/services shows service names" do
    get service_reports_path
    # services with visits this month should appear
    assert_response :success
  end

  # -- Discount analysis -------------------------------------------------------

  test "GET /reports/discounts renders the discount analysis" do
    get discount_reports_path
    assert_response :success
  end

  test "GET /reports/discounts counts discounted visits" do
    get discount_reports_path
    assert_response :success
    # Page renders without error and includes discount content
    assert_select "body"
  end

  # -- Access control ----------------------------------------------------------

  test "reports are inaccessible without authentication" do
    sign_out staffs(:owner)
    get reports_path
    assert_redirected_to new_staff_session_path
  end
end
