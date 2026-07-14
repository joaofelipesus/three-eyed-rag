require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "relations" do
    tag = Tag.new

    assert_respond_to tag, :note_tags
  end

  test "is invalid without a name" do
    tag = Tag.new(name: nil)

    assert_not tag.valid?
    assert_equal ["can't be blank"], tag.errors[:name]
  end

  test "is invalid with a duplicate name" do
    tag = Tag.new(name: tags(:ruby).name)

    assert_not tag.valid?
    assert_equal ["has already been taken"], tag.errors[:name]
  end
end
