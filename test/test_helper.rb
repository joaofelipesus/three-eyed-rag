ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"
require_relative "support/vector_fixtures"

# Active Storage resolves and memoizes config/storage.yml against Rails.root the first
# time ActiveStorage::Blob loads in this process (see the activestorage engine's
# "active_storage.services" initializer). Forcing that to happen now, before any test
# runs, means a test that stubs Rails.root (e.g. to point at a fake vault directory)
# can't accidentally be the one that triggers it — which would make it resolve the
# config path against the stub instead of the real app root and raise.
ActiveStorage::Blob.service

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order,
    # except note_embeddings/note_section_embeddings — see VectorFixtures for why those
    # two are seeded separately instead of through the normal YAML fixture loader.
    fixtures(*(Dir[Rails.root.join("test/fixtures/*.yml")].map { |path| File.basename(path, ".yml") } - VectorFixtures::TABLE_NAMES))
    include VectorFixtures

    # Add more helper methods to be used by all tests here...
  end
end
