require "test_helper"

# Verifies the embedded subscription template wires the stripe-elements Stimulus
# controller correctly: the data-controller name, every data-*-target, and the
# value attributes the controller reads on connect(). This is the only custom
# Stimulus controller in the app, so this single view test covers JS surface.
#
# Rendered in isolation (no controller, no Stripe round-trip) so the test runs
# fully offline and stays out of Account::SubscriptionsController's lane.
class AccountSubscriptionsEmbeddedViewTest < ActionView::TestCase
  test "renders the stripe-elements Stimulus controller with all its targets and values" do
    @plan          = :pro
    @client_secret = "pi_test_client_secret_abc"

    html = render(template: "account/subscriptions/embedded", layout: false)

    # Controller mount point + value attributes the JS controller reads.
    assert_includes html, 'data-controller="stripe-elements"'
    assert_includes html, "data-stripe-elements-publishable-key-value="
    assert_includes html, 'data-stripe-elements-client-secret-value="pi_test_client_secret_abc"'
    assert_includes html, "data-stripe-elements-return-url-value="

    # Every target the JS controller looks up: form, paymentElement, errors, submit.
    assert_includes html, 'data-stripe-elements-target="form"'
    assert_includes html, 'data-stripe-elements-target="paymentElement"'
    assert_includes html, 'data-stripe-elements-target="errors"'
    assert_includes html, 'data-stripe-elements-target="submit"'
  end
end
