require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "is invalid without a title" do
    conversation = Conversation.new(title: nil)

    assert_not conversation.valid?
    assert_equal ["can't be blank"], conversation.errors[:title]
  end

  test "is invalid with a duplicate title" do
    conversation = Conversation.new(title: conversations(:architecture_walkthrough).title)

    assert_not conversation.valid?
    assert_equal ["has already been taken"], conversation.errors[:title]
  end
end
