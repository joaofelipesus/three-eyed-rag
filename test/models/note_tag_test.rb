require "test_helper"

class NoteTagTest < ActiveSupport::TestCase
  test "relations" do
    note_tag = NoteTag.new

    assert_respond_to note_tag, :note
    assert_respond_to note_tag, :tag
  end
end
