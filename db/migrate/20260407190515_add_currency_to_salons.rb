class AddCurrencyToSalons < ActiveRecord::Migration[8.1]
  def change
    add_column :salons, :currency, :string, default: "NGN", null: false
  end
end
