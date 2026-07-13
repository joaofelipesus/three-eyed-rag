class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.string :path, null: false, comment: "The path on user system"
      t.string :title, null: false, comment: "Note title"
      t.datetime :last_updated_at, comment: "The last time the note was updated in the system"
      t.datetime :last_embeded_at, comment: "The last time was generated the note embeddings"
      t.string :checksum, comment: "A checksum with the content of the note"
      t.text :content, comment: "The note content"

      t.timestamps
    end
  end
end
