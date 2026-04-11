class AddDefaultToCustomerVisitsCount < ActiveRecord::Migration[8.1]
  def change
    change_column_default :customers, :visits_count, from: nil, to: 0
  end
end
