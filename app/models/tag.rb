class Tag < ApplicationRecord
  has_many :note_tags

  validates :name, presence: true
  validates :name, uniqueness: true
end
