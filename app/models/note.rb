class Note < ApplicationRecord
  include Notes::VaultProcessable
  include Notes::Embeddable
  include Notes::Chatable
  include Checksummable

  has_one :note_embedding
  has_many :note_tags
  has_many :note_sections

  enum :processing_status, { pending: "pending", processed: "processed", failed: "failed" }

  validates :title, :path, presence: true
end
