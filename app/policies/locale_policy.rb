# frozen_string_literal: true

# Any signed-in user can flip the session locale. Pundit resolves
# `authorize :locale` to `LocalePolicy.new(user, :locale).update?`, which
# inherits `signed_in?` from AuthenticatedPolicy.
class LocalePolicy < AuthenticatedPolicy
end
