require "test_helper"

class NoteEmbeddingTest < ActiveSupport::TestCase
  test "fixture note_embedding is valid" do
    assert note_embeddings(:embedded).valid?
  end

  test "is invalid without an embedding" do
    note_embedding = NoteEmbedding.new(note: notes(:embedded), embedding: nil)

    assert_not note_embedding.valid?
    assert_equal [ "can't be blank" ], note_embedding.errors[:embedding]
  end

  test "is invalid when the embedding does not have #{NoteEmbedding::DIMENSIONS} dimensions" do
    note_embedding = NoteEmbedding.new(note: notes(:embedded), embedding: [ 0.1, 0.2, 0.3 ])

    assert_not note_embedding.valid?
    assert_equal [ "must have #{NoteEmbedding::DIMENSIONS} dimensions" ], note_embedding.errors[:embedding]
  end

  test "uses note_id as its primary key" do
    assert_equal "note_id", NoteEmbedding.primary_key
  end

  test "ignores the vec0 pseudo-columns" do
    assert_equal %w[distance k], NoteEmbedding.ignored_columns
  end

  test "casts the embedding attribute with VectorType" do
    assert_instance_of VectorType, NoteEmbedding.type_for_attribute("embedding")
  end

  test "round-trips the embedding through VectorType" do
    note_embedding = note_embeddings(:embedded)

    assert_equal NoteEmbedding::DIMENSIONS, note_embedding.embedding.size
    assert_in_delta 0.1, note_embedding.embedding.first, 0.0001
  end
end
