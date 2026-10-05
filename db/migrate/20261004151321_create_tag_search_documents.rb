class CreateTagSearchDocuments < ActiveRecord::Migration[8.1]
  def up
    create_table :tag_search_documents do |t|
      t.string :tag_id, null: false
    end
    add_index :tag_search_documents, :tag_id, unique: true

    # same tokenizer as note_search_documents_fts: substring matches, accents ignored
    create_virtual_table :tag_search_documents_fts, :fts5, [ "name", "tokenize='trigram remove_diacritics 1'" ]

    # index the tags that already exist; new and changed ones are indexed by has_search callbacks
    Tag.reset_column_information
    Tag.find_each(&:reindex)
  end

  def down
    drop_table :tag_search_documents_fts
    drop_table :tag_search_documents
  end
end
