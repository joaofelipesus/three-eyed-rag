require "test_helper"

class NoteTest < ActiveSupport::TestCase
  test "relations" do
    note = Note.new

    assert_respond_to note, :note_embedding
    assert_respond_to note, :note_tags
  end

  test "fixture note is valid" do
    assert notes(:embedded).valid?
  end

  test "is invalid without a title or path and reports the errors" do
    note = Note.new(title: nil, path: nil)

    assert_not note.valid?
    assert_equal ["can't be blank"], note.errors[:title]
    assert_equal ["can't be blank"], note.errors[:path]
  end
end
