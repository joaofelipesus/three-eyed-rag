require "test_helper"

class NoteSectionTest < ActiveSupport::TestCase
  test "relations" do
    note_section = NoteSection.new

    assert_respond_to note_section, :note
    assert_respond_to note_section, :previous_note
    assert_respond_to note_section, :follow_note
    assert_respond_to note_section, :note_section_embedding
    assert_respond_to note_section, :images
  end

  test "fixture chain links previous and follow sections" do
    assert_nil note_sections(:first).previous_note
    assert_equal note_sections(:second), note_sections(:first).follow_note

    assert_equal note_sections(:first), note_sections(:second).previous_note
    assert_nil note_sections(:second).follow_note
  end

  test "is invalid without content" do
    note_section = NoteSection.new(note: notes(:embedded), content: nil)

    assert_not note_section.valid?
    assert_equal ["can't be blank"], note_section.errors[:content]
  end

  test "is valid without a previous_note or follow_note" do
    note_section = NoteSection.new(note: notes(:embedded), content: "text")

    assert note_section.valid?
  end
end
