module OwnerRequired
  extend ActiveSupport::Concern

  included do
    before_action :require_owner!
  end

  private
    def require_owner!
      if Current.staff.nil?
        redirect_to new_staff_session_path, alert: "Please sign in to continue."
      elsif !Current.staff.owner?
        redirect_to dashboard_path, alert: "Only the salon owner can access this."
      end
    end
end
