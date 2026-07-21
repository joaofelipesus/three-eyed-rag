class Note < ApplicationRecord
  include Notes::VaultProcessable
  include Notes::Embeddable

  has_one :note_embedding
  has_many :note_tags
  has_many :note_sections

  validates :title, :path, presence: true
end
