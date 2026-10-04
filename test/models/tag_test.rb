require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "relations" do
    tag = Tag.new

    assert_respond_to tag, :note_tags
  end

  test "is invalid without a name" do
    tag = Tag.new(name: nil)

    assert_not tag.valid?
    assert_equal [ "can't be blank" ], tag.errors[:name]
  end

  test "is invalid with a duplicate name" do
    tag = Tag.new(name: tags(:ruby).name)

    assert_not tag.valid?
    assert_equal [ "has already been taken" ], tag.errors[:name]
  end

  test "search_by_tag_name matches part of a tag name" do
    Tag.find_each(&:reindex)

    assert_equal [ tags(:rails) ], Tag.search_by_tag_name("ail")
    assert_equal [ tags(:ruby) ], Tag.search_by_tag_name("ru")
  end
end
