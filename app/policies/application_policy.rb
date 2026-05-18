# frozen_string_literal: true

# Default-deny base. Concrete policies should inherit from AuthenticatedPolicy
# (every action signed-in users get) and override show?/destroy?/etc. where
# the record requires ownership.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user   = user
    @record = record
  end

  def index?;   false; end
  def show?;    false; end
  def create?;  false; end
  def new?;     create?; end
  def update?;  false; end
  def edit?;    update?; end
  def destroy?; false; end

  protected

  def signed_in?
    user.present?
  end

  # True when the record's effective owner is the current user. Handles two
  # ownership shapes: Pay records (record.customer.owner) and bare AR models
  # (record.user). Class arguments (e.g. authorize Pay::Subscription) are
  # treated as "ownership not applicable here" -- inheriting policies should
  # guard those at the action level.
  def owned?
    return false unless signed_in?
    return false if record.is_a?(Class)

    resolve_owner == user
  end

  def resolve_owner
    if record.respond_to?(:customer) && record.customer.respond_to?(:owner)
      record.customer.owner
    elsif record.respond_to?(:user)
      record.user
    end
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user  = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "#{self.class} must implement #resolve"
    end
  end
end
