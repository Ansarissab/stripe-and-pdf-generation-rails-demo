module LocaleSwitching
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
  end

  private

  # Reads `session[:locale]` and wraps the action in `I18n.with_locale` so the
  # surrounding view, mailer, and PDF rendering all see the chosen locale —
  # and the next request inherits the same default again without leakage.
  def switch_locale(&action)
    requested = session[:locale]&.to_sym
    locale    = I18n.available_locales.include?(requested) ? requested : I18n.default_locale
    I18n.with_locale(locale, &action)
  end
end
