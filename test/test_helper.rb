ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"
require_relative "support/vector_fixtures"

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
