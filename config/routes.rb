Rails.application.routes.draw do
  devise_for :users

  namespace :account do
    resource :subscription, only: %i[show new create destroy] do
      collection do
        post :embedded         # Stripe Elements (PaymentElement) — creates a default_incomplete sub
        get  :success          # Hosted Checkout success_url lands here
        get  :cancel           # Hosted Checkout cancel_url lands here
        post :billing_portal   # Redirects to Stripe-hosted billing portal
      end
    end

    resources :invoices, only: %i[index show]
  end

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#show"
end
