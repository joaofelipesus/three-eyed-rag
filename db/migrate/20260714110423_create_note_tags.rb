class CreateNoteTags < ActiveRecord::Migration[8.1]
  def change
    create_table :note_tags do |t|
      t.references :note, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
  end
end
