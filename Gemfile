source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache and Active Job
gem "solid_cache"
gem "solid_queue"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# Slim templates (preferred over ERB project-wide)
gem "slim-rails", "4.0.0"

# Authentication and authorization
gem "devise", "5.0.4"
gem "pundit", "2.5.2"

# Stripe subscription billing (Pay wraps Stripe + the hosted billing portal)
gem "pay", "11.6.1"
gem "stripe", "19.1.0"

# PDF generation (pure Ruby, no binary deps)
gem "hexapdf", "1.8.0"

# Minimal admin dashboard (separate AdminUser; lives at /admin)
gem "activeadmin", "3.5.1"
gem "sassc-rails", require: false

group :development, :test do
  # Loads local secrets from .env (.env is gitignored; .env.example is the committed template)
  gem "dotenv-rails", "3.2.0"

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :test do
  # Code coverage reporting
  gem "simplecov", require: false

  # Stub external HTTP (Stripe, etc.) so tests are deterministic and offline-safe
  gem "webmock"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # N+1 query detector and unused eager-loading detector
  gem "bullet", "8.1.1"

  # Catches outbound mail in dev and browse it at /letter_opener -- pairs with
  # Devise :confirmable so the confirmation links are clickable without SMTP.
  gem "letter_opener_web", "3.0.0"
end
