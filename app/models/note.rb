class Note < ApplicationRecord
  # rows of the :notes search index (config/search.rb), written by has_search
  class SearchDocument < ApplicationRecord
    self.table_name = "note_search_documents"
  end

  VAULT_DIRECTORY = "/obsidian_vault/"

  include Notes::VaultProcessable
  include Notes::Embeddable
  include Notes::Chatable
  include Checksummable
  include NameSearchable

  has_one :note_embedding
  has_many :note_tags, dependent: :destroy
  has_many :tags, through: :note_tags
  has_many :note_sections

  enum :processing_status, { pending: "pending", processed: "processed", failed: "failed" }

  validates :title, :path, presence: true

  # keeps the :notes search index in sync on save/destroy; inline, since it's one small SQLite write
  has_search async: false

  # the chat input's "#" autocomplete, matched by file name
  def self.search_by_title(query, **options)
    search_by_name(:title, query, **options)
  end

  # folders from the vault root down to the note, e.g. [ "Notes", "Rails", "helpers" ]
  def folders
    File.dirname(path.split(VAULT_DIRECTORY, 2).last).split("/") - [ "." ]
  end
end
