class CreateNoteSections < ActiveRecord::Migration[8.1]
  def change
    create_table :note_sections do |t|
      t.references :note, null: false, foreign_key: true
      t.text :content
      t.references :previous_note, foreign_key: { to_table: :note_sections }
      t.references :follow_note, foreign_key: { to_table: :note_sections }

      t.timestamps
    end
  end
end
