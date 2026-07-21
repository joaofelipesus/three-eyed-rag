class Note < ApplicationRecord
  include Notes::VaultProcessable
  include Notes::Embeddable

  has_one :note_embedding
  has_many :note_tags
  has_many :note_sections

  validates :title, :path, presence: true

  before_save :generate_checksum, if: :content_changed?

  private

  def generate_checksum
    self.checksum = Digest::SHA256.hexdigest(content.to_s)
  end
end
