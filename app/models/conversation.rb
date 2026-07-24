class Conversation < ApplicationRecord
  validates :title, presence: true, uniqueness: true
end
