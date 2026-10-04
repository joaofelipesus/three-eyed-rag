class Note < ApplicationRecord
  VAULT_DIRECTORY = "/obsidian_vault/"

  include Notes::VaultProcessable
  include Notes::Embeddable
  include Notes::Chatable
  include Checksummable

  has_one :note_embedding
  has_many :note_tags
  has_many :note_sections

  enum :processing_status, { pending: "pending", processed: "processed", failed: "failed" }

  validates :title, :path, presence: true

  # folders from the vault root down to the note, e.g. [ "Notes", "Rails", "helpers" ]
  def folders
    File.dirname(path.split(VAULT_DIRECTORY, 2).last).split("/") - [ "." ]
  end
end
