require "test_helper"

class ChecksummableTest < ActiveSupport::TestCase
  test "generates a SHA256 checksum of the content on create" do
    note = Note.create!(title: "t", path: "p", content: "hello world")

    assert_equal Digest::SHA256.hexdigest("hello world"), note.checksum
  end

  test "regenerates the checksum when content changes" do
    note = notes(:embedded)
    original_checksum = note.checksum

    note.update!(content: "new content")

    assert_equal Digest::SHA256.hexdigest("new content"), note.checksum
    assert_not_equal original_checksum, note.checksum
  end

  test "does not recompute the checksum when content is unchanged" do
    note = notes(:embedded)
    original_checksum = note.checksum

    note.update!(title: "New title")

    assert_equal original_checksum, note.reload.checksum
  end
end
