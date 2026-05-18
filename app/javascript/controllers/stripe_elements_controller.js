import { Controller } from "@hotwired/stimulus"

// Mounts Stripe PaymentElement and confirms payment for a default_incomplete
// subscription. The server pre-creates the subscription and hands us the
// PaymentIntent's client_secret; we collect the card here and confirm.
export default class extends Controller {
  static values  = { publishableKey: String, clientSecret: String, returnUrl: String }
  static targets = ["form", "paymentElement", "errors", "submit"]

  async connect() {
    if (!this.publishableKeyValue || !this.clientSecretValue) {
      this.#showError("Stripe is not configured. Set STRIPE_PUBLIC_KEY and reload.")
      return
    }

    try {
      await this.#ensureStripeJs()
      this.stripe   = window.Stripe(this.publishableKeyValue)
      this.elements = this.stripe.elements({ clientSecret: this.clientSecretValue })
      this.elements.create("payment").mount(this.paymentElementTarget)
      this.formTarget.addEventListener("submit", (e) => this.#submit(e))
    } catch (err) {
      this.#showError(`Couldn't load Stripe: ${err.message}`)
    }
  }

  async #submit(event) {
    event.preventDefault()
    this.#clearError()
    this.submitTarget.disabled    = true
    this.submitTarget.textContent = "Processing…"

    const { error } = await this.stripe.confirmPayment({
      elements: this.elements,
      confirmParams: { return_url: this.returnUrlValue }
    })

    if (error) {
      this.#showError(error.message || "Payment failed. Try a different card.")
      this.submitTarget.disabled    = false
      this.submitTarget.textContent = "Try again"
    }
    // On success Stripe redirects to return_url; webhook updates the sub.
  }

  #ensureStripeJs() {
    if (window.Stripe) return Promise.resolve()
    return new Promise((resolve, reject) => {
      const s = document.createElement("script")
      s.src     = "https://js.stripe.com/v3/"
      s.onload  = resolve
      s.onerror = () => reject(new Error("Stripe.js failed to load"))
      document.head.appendChild(s)
    })
  }

  #showError(message) {
    this.errorsTarget.textContent = message
    this.errorsTarget.classList.remove("hidden")
  }

  #clearError() {
    this.errorsTarget.textContent = ""
    this.errorsTarget.classList.add("hidden")
  }
}
