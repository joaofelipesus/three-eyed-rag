class Note < ApplicationRecord
  has_one :note_embedding
  has_many :note_tags

  validates :title, :path, presence: true
end
