class ExpensesController < ApplicationController
  before_action :authenticate_staff!
  before_action :set_expense, only: %i[ edit update destroy ]

  def index
    @expenses = Expense.includes(:staff).order(incurred_on: :desc)

    if params[:month].present?
      year, month = params[:month].split("-").map(&:to_i)
      @expenses = @expenses.for_month(year, month)
      @selected_month = Date.new(year, month)
    else
      @expenses = @expenses.this_month
      @selected_month = Date.current
    end

    @total = @expenses.sum(:amount)
    @by_category = @expenses.unscope(:order).group(:category).sum(:amount)
  end

  def new
    @expense = Expense.new(incurred_on: Date.today)
  end

  def create
    @expense = Expense.new(expense_params)
    @expense.salon = current_salon
    @expense.staff = current_staff

    if @expense.save
      redirect_to expenses_path, notice: "Expense logged."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      redirect_to expenses_path, notice: "Expense updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    redirect_to expenses_path, notice: "Expense deleted."
  end

  private
    def set_expense
      @expense = Expense.find(params[:id])
    end

    def expense_params
      params.require(:expense).permit(:amount, :category, :description, :incurred_on)
    end
end
