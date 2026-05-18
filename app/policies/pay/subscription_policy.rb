class Pay::SubscriptionPolicy < AuthenticatedPolicy
  def destroy?
    owned?
  end

  def billing_portal?
    signed_in?
  end
end
