class ConversationMessage < ApplicationRecord
  # touches conversation whenever a new ConversationMessage is created, this keeps the conversation in evidence.
  belongs_to :conversation, touch: true
  has_many_attached :images

  enum :created_by, { user: "user", system: "system" }

  validates :content, presence: true
end
