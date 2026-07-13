class CreateNoteEmbeddings < ActiveRecord::Migration[8.1]
  def change
    create_virtual_table :note_embeddings, :vec0, [
      "note_id integer primary key",
      "embedding float[1024]"
    ]
  end
end
