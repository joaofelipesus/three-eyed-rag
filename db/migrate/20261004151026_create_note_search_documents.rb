class CreateNoteSearchDocuments < ActiveRecord::Migration[8.1]
  def up
    create_table :note_search_documents do |t|
      t.string :note_id, null: false
    end
    add_index :note_search_documents, :note_id, unique: true

    # trigram: matches any 3+ character substring of a word ("archi" finds "Architecture"), which the
    # default word tokenizer can't do since active_search quotes "*" prefix queries;
    # remove_diacritics: "definicao" finds "Definição"
    create_virtual_table :note_search_documents_fts, :fts5, [ "title", "tokenize='trigram remove_diacritics 1'" ]

    # index the notes that already exist; new and changed ones are indexed by has_search callbacks
    Note.reset_column_information
    Note.find_each(&:reindex)
  end

  def down
    drop_table :note_search_documents_fts
    drop_table :note_search_documents
  end
end
