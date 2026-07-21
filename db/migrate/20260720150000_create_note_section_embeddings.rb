class CreateNoteSectionEmbeddings < ActiveRecord::Migration[8.1]
  def change
    create_virtual_table :note_section_embeddings, :vec0, [
      "note_section_id integer primary key",
      "embedding float[2560]"
    ]
  end
end
