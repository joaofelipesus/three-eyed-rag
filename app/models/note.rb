class Note < ApplicationRecord
  has_one :note_embedding

  validates :title, :path, presence: true
end
