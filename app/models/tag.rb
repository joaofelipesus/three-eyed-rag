class Tag < ApplicationRecord
  include NameSearchable

  # rows of the :tags search index (config/search.rb), written by has_search
  class SearchDocument < ApplicationRecord
    self.table_name = "tag_search_documents"
  end

  has_many :note_tags
  has_many :notes, through: :note_tags

  validates :name, presence: true
  validates :name, uniqueness: true

  # keeps the :tags search index in sync on save/destroy; inline, since it's one small SQLite write
  has_search async: false

  # the chat input's "@" autocomplete
  def self.search_by_tag_name(query, **options)
    search_by_name(:name, query, **options)
  end
end
