ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# SimpleCov must start *before* Rails boots so `Coverage` probes get inserted
# into every file Rails loads. `bin/rails test` (no path arg) runs the
# `test:prepare` rake task first, which boots Rails before `test_helper.rb`
# has a chance to require SimpleCov -- by the time Coverage starts, the
# Billing concern, PlanSync concern, and most of Rails are already loaded and
# invisible to SimpleCov. Starting here at boot fixes that.
if (ENV["RAILS_ENV"] || ARGV.first) == "test"
  require_relative "simplecov_setup"
end

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
