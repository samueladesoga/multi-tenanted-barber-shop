ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # Load all fixtures in test/fixtures/*.yml
    fixtures :all

    # Convenience helper for tenant-scoped model tests
    def with_tenant(salon, &)
      ActsAsTenant.with_tenant(salon, &)
    end
  end
end

# Devise integration helpers and a modern User-Agent for all request tests.
# Rails 8's allow_browser check rejects requests with no/old User-Agent.
class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Rails 8's allow_browser check rejects requests with no User-Agent.
  # Inject a modern UA into every HTTP call made from integration tests.
  MODERN_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
              "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  def process(method, path, **kwargs)
    kwargs[:headers] = { "User-Agent" => MODERN_UA }.merge(kwargs[:headers] || {})
    super
  end
end
