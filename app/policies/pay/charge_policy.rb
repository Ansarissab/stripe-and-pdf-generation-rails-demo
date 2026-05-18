class Pay::ChargePolicy < AuthenticatedPolicy
  def show?
    return signed_in? if record.is_a?(Class)

    owned?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      scope.joins(:customer)
           .where(pay_customers: { owner_id: user.id, owner_type: "User" })
    end
  end
end
