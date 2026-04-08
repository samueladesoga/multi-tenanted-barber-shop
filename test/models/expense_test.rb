require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  setup do
    @salon = salons(:demo)
  end

  # -- category_label ----------------------------------------------------------

  test "category_label humanizes the enum key" do
    with_tenant(@salon) do
      assert_equal "Rent",     expenses(:monthly_rent).category_label
      assert_equal "Supplies", expenses(:supplies_order).category_label
    end
  end

  # -- Scopes ------------------------------------------------------------------

  test "this_month scope returns expenses in the current month" do
    with_tenant(@salon) do
      result = Expense.this_month
      assert_includes result, expenses(:monthly_rent)
      assert_includes result, expenses(:supplies_order)
    end
  end

  test "for_month scope returns expenses in the specified month" do
    with_tenant(@salon) do
      result = Expense.for_month(Date.today.year, Date.today.month)
      assert_includes result, expenses(:monthly_rent)
    end
  end

  test "for_month scope excludes expenses from other months" do
    with_tenant(@salon) do
      last_month = Date.today.prev_month
      old_expense = Expense.create!(
        amount: 50, category: :supplies, description: "Old stock",
        incurred_on: last_month.beginning_of_month,
        salon: @salon, staff: staffs(:owner)
      )
      result = Expense.for_month(Date.today.year, Date.today.month)
      assert_not_includes result, old_expense
    end
  end
end
