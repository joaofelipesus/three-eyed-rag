class NoteSection < ApplicationRecord
  belongs_to :note
  belongs_to :previous_note, class_name: "NoteSection", optional: true
  belongs_to :follow_note, class_name: "NoteSection", optional: true
  has_one :note_section_embedding

  validates :content, presence: true
end
