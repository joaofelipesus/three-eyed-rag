class ConversationMessage < ApplicationRecord
  belongs_to :conversation
  has_many_attached :images

  enum :created_by, { user: "user", system: "system" }

  validates :content, presence: true
end
