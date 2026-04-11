class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_current_tenant

  helper_method :current_salon, :nav_link_class

  private
    def set_current_tenant
      return unless request.subdomain.present?

      salon = Salon.find_by(subdomain: request.subdomain)

      if salon
        ActsAsTenant.current_tenant = salon
        Current.salon = salon
      else
        redirect_to marketing_root_url(subdomain: false), alert: "Salon not found.", allow_other_host: true
      end
    end

    def current_salon
      Current.salon
    end

    def current_staff
      Current.staff ||= current_devise_staff
    end

    def current_devise_staff
      warden.authenticate(scope: :staff)
    end

    def authenticate_staff!
      return redirect_to new_staff_session_path, alert: "Please sign in to continue." unless staff_signed_in?
      Current.staff = warden.authenticate(scope: :staff)
    end

    def after_sign_in_path_for(_resource)
      dashboard_path
    end

    def nav_link_class(section)
      base    = "px-3 py-2 rounded-md text-sm font-medium transition-colors"
      active  = controller_name == section
      active ? "#{base} bg-amber-500 text-white" : "#{base} text-gray-300 hover:text-white hover:bg-gray-700"
    end
end
