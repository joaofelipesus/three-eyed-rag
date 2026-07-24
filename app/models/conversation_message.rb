class ConversationMessage < ApplicationRecord
  # updates conversation's updated_at timestamp on any change to keep it in evidence
  belongs_to :conversation, touch: true
  has_many_attached :images

  enum :created_by, { user: "user", system: "system" }

  validates :content, presence: true
end
