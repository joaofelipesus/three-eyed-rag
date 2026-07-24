class Conversation < ApplicationRecord
  has_many :conversation_messages, dependent: :destroy

  validates :title, presence: true, uniqueness: true
end
