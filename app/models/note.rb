class Note < ApplicationRecord
  validates :title, :path, presence: true
end
