class Staffs::SessionsController < Devise::SessionsController
  def create
    # Override to scope login to the current salon
    self.resource = warden.authenticate(auth_options)

    if resource && resource.salon == current_salon
      sign_in(resource_name, resource)
      respond_with resource, location: after_sign_in_path_for(resource)
    else
      set_flash_message!(:alert, :invalid)
      redirect_to new_staff_session_path
    end
  end
end
