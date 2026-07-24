class Conversation < ApplicationRecord
  has_many :conversation_messages, dependent: :destroy

  validates :title, presence: true, uniqueness: true

  scope :ordered, -> { order(updated_at: :desc) }

  def self.start!
    create!(title: Time.current.strftime("%Y-%m-%d %H:%M:%S.%6N"))
  end
end
