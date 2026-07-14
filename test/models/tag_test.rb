require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "is invalid without a name" do
    tag = Tag.new(name: nil)

    assert_not tag.valid?
    assert_equal ["can't be blank"], tag.errors[:name]
  end

  test "is invalid with a duplicate name" do
    tag = Tag.new(name: tags(:one).name)

    assert_not tag.valid?
    assert_equal ["has already been taken"], tag.errors[:name]
  end
end
