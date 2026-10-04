require "test_helper"

class NoteSectionEmbeddingTest < ActiveSupport::TestCase
  test "fixture note_section_embedding is valid" do
    assert note_section_embeddings(:first).valid?
  end

  test "is invalid without an embedding" do
    note_section_embedding = NoteSectionEmbedding.new(note_section: note_sections(:first), embedding: nil)

    assert_not note_section_embedding.valid?
    assert_equal [ "can't be blank" ], note_section_embedding.errors[:embedding]
  end

  test "is invalid when the embedding does not have #{NoteSectionEmbedding::DIMENSIONS} dimensions" do
    note_section_embedding = NoteSectionEmbedding.new(note_section: note_sections(:first), embedding: [ 0.1, 0.2, 0.3 ])

    assert_not note_section_embedding.valid?
    assert_equal [ "must have #{NoteSectionEmbedding::DIMENSIONS} dimensions" ], note_section_embedding.errors[:embedding]
  end

  test "uses note_section_id as its primary key" do
    assert_equal "note_section_id", NoteSectionEmbedding.primary_key
  end

  test "ignores the vec0 pseudo-columns" do
    assert_equal %w[distance k], NoteSectionEmbedding.ignored_columns
  end

  test "casts the embedding attribute with VectorType" do
    assert_instance_of VectorType, NoteSectionEmbedding.type_for_attribute("embedding")
  end

  test "round-trips the embedding through VectorType" do
    note_section_embedding = note_section_embeddings(:first)

    assert_equal NoteSectionEmbedding::DIMENSIONS, note_section_embedding.embedding.size
    assert_in_delta 0.1, note_section_embedding.embedding.first, 0.0001
  end
end
