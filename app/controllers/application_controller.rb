class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include LocaleSwitching

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = I18n.t("flash.not_authorized")
    redirect_back fallback_location: root_path
  end
end
