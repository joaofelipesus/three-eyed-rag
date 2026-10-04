require "test_helper"
require "capybara/cuprite"

# Browser tests (bin/rails test:system), for behavior that needs JavaScript: Stimulus controllers,
# Turbo Streams and full user flows. Everything else belongs in integration tests, which are much faster.
# Chrome comes from BROWSER_PATH (set in Dockerfile.dev) or the system install.
Capybara.server = :puma, { Silent: true }

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # no-sandbox: Chrome refuses to start as root inside Docker otherwise. js_errors fails the test on
  # uncaught JavaScript exceptions.
  driven_by :cuprite, screen_size: [ 1400, 1000 ],
                      options: { js_errors: true, process_timeout: 20, browser_options: { "no-sandbox" => nil } }

  # The test env disables CSRF protection, which also drops the csrf-token meta tag that
  # chat_controller.js sends with its fetch; turn it back on so browser tests match production.
  setup do
    @original_allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_allow_forgery_protection
  end
end
