# frozen_string_literal: true

# Authenticated-default policy: every standard CRUD action returns true when
# the user is signed in. Use as the base for app-owned resources where mere
# authentication is enough; override individual actions to require ownership
# (call `owned?` from ApplicationPolicy).
class AuthenticatedPolicy < ApplicationPolicy
  def index?;   signed_in?; end
  def show?;    signed_in?; end
  def create?;  signed_in?; end
  def update?;  signed_in?; end
  def destroy?; signed_in?; end
end
