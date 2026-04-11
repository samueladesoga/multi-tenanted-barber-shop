class SalonHomeController < ApplicationController
  def index
    @services = Service.active.order(:name)
  end
end
