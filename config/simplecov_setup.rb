require "simplecov"

SimpleCov.start "rails" do
  add_filter "/test/"

  # Rails-generated framework boilerplate with no executable body. The only
  # lines in these files are `class X < Y` (loaded at file-load, not test) so
  # SimpleCov reports them at 0% no matter what. Excluding rather than gaming
  # the number with a test that asserts nothing.
  add_filter "app/jobs/application_job.rb"
  add_filter "app/mailers/application_mailer.rb"
  add_filter "app/models/application_record.rb"
  add_filter "app/helpers/application_helper.rb"

  # Ops/runbook rake tasks that hit Stripe in production. Documented in
  # docs/runbooks/stripe.md; intentionally out of scope for the test suite.
  add_filter "lib/tasks/subscriptions.rake"

  # Build-time SCSS compile for ActiveAdmin. Runs via bin/setup and is
  # enhanced into assets:precompile; not exercised by the test suite.
  add_filter "lib/tasks/active_admin.rake"

  # ActiveAdmin DSL files (app/admin/*.rb) are configuration, not logic --
  # registrations, columns, filters. The admin namespace is a smoke-tested
  # boundary, not a unit-tested module. Same applies to the generated
  # AdminUser model (Devise-only, no business code) and the Pay-gem
  # Ransack allowlist (class_eval into vendored models, also config).
  add_filter "app/admin/"
  add_filter "app/models/admin_user.rb"
  add_filter "config/initializers/pay_ransackable.rb"

  # Hard floor. Suite currently sits at 100%; 90% leaves room for a single new
  # uncovered branch to land without breaking CI, but stops a slow drift back
  # to the 40% baseline this gate was introduced to prevent.
  minimum_coverage line: 90
end
