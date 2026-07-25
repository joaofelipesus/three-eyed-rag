# `note_embeddings` and `note_section_embeddings` are sqlite-vec `vec0` virtual tables
# (see db/schema.rb). Rails' fixture loader inserts a whole table's rows through one
# batched, multi-statement SQL call, and vec0's internal blob storage can't be written to
# that way (raises "could not open vector blob..."). This seeds equivalent data through
# plain, one-row-at-a-time ActiveRecord inserts instead, and exposes `note_embeddings(:name)`
# / `note_section_embeddings(:name)` accessors matching the ones YAML fixtures would have
# generated, keyed to the same labels used in notes.yml / note_sections.yml.
module VectorFixtures
  extend ActiveSupport::Concern

  TABLE_NAMES = %w[note_embeddings note_section_embeddings].freeze

  NOTE_EMBEDDINGS = {
    embedded: 0.1,
    pending_embedding: -0.1
  }.freeze

  NOTE_SECTION_EMBEDDINGS = {
    first: 0.1,
    second: -0.1
  }.freeze

  included do
    setup :load_vector_fixtures
  end

  def note_embeddings(*labels)
    find_vector_records(NoteEmbedding, labels)
  end

  def note_section_embeddings(*labels)
    find_vector_records(NoteSectionEmbedding, labels)
  end

  private

  def find_vector_records(model_class, labels)
    records = labels.map { |label| model_class.find(ActiveRecord::FixtureSet.identify(label)) }
    records.size == 1 ? records.first : records
  end

  # vec0 virtual tables don't roll back with the per-test transaction the way normal
  # tables do, so rows inserted by an earlier test in the same worker process are still
  # there when the next test's setup runs. Only insert what's actually missing.
  def load_vector_fixtures
    NOTE_EMBEDDINGS.each do |label, fill|
      note_id = ActiveRecord::FixtureSet.identify(label)
      next if NoteEmbedding.exists?(note_id)

      NoteEmbedding.create!(note_id: note_id, embedding: Array.new(NoteEmbedding::DIMENSIONS, fill))
    end

    NOTE_SECTION_EMBEDDINGS.each do |label, fill|
      note_section_id = ActiveRecord::FixtureSet.identify(label)
      next if NoteSectionEmbedding.exists?(note_section_id)

      NoteSectionEmbedding.create!(
        note_section_id: note_section_id,
        embedding: Array.new(NoteSectionEmbedding::DIMENSIONS, fill)
      )
    end
  end
end
