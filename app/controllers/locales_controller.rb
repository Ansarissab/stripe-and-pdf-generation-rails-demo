class LocalesController < ApplicationController
  def update
    authorize :locale
    requested = params[:locale]&.to_sym
    session[:locale] = requested if I18n.available_locales.include?(requested)
    redirect_back fallback_location: root_path
  end
end
