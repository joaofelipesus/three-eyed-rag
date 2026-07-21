class AddChecksumToNoteSections < ActiveRecord::Migration[8.1]
  def change
    add_column :note_sections, :checksum, :string, comment: "A checksum with the content of the note section"
  end
end
