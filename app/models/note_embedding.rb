class NoteEmbedding < ApplicationRecord
  DIMENSIONS = 1024

  # use the same id as the related note id because this model doesn't use a a actual table, it uses a vec0 virtual
  # table. So to match the relation it preserves the same id as the related fk value
  self.primary_key = "note_id"

  # vec0 virtual tables implicitly expose "distance" and "k" pseudo-columns used
  # only for KNN query syntax (`WHERE embedding MATCH ? AND k = ?`); they aren't
  # real stored columns, so they must be ignored or inserts/updates break.
  self.ignored_columns = %w[distance k]

  # uses a custom type to handle the parse from the raw data returned by the database to
  # a friendly type on rails, so it will be simple to work with the attribute, otherwise
  # it will be make manual casting operations befoce instantiate and before parse objects.
  attribute :embedding, VectorType.new(dimensions: DIMENSIONS)

  belongs_to :note

  validates :embedding, presence: true
  validate :embedding_has_correct_dimensions

  private

  def embedding_has_correct_dimensions
    return if embedding.blank?
    return if embedding.size == DIMENSIONS

    errors.add(:embedding, "must have #{DIMENSIONS} dimensions")
  end
end
