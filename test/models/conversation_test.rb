require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "is invalid without a title" do
    conversation = Conversation.new(title: nil)

    assert_not conversation.valid?
    assert_equal [ "can't be blank" ], conversation.errors[:title]
  end

  test "is invalid with a duplicate title" do
    conversation = Conversation.new(title: conversations(:architecture_walkthrough).title)

    assert_not conversation.valid?
    assert_equal [ "has already been taken" ], conversation.errors[:title]
  end

  test "start! creates a conversation titled with the current timestamp" do
    travel_to Time.zone.local(2026, 7, 24, 11, 5, 32) do
      conversation = Conversation.start!

      assert_equal "2026-07-24 11:05:32.000000", conversation.title
    end
  end

  test "ordered lists conversations most recently updated first" do
    conversations(:architecture_walkthrough).touch

    assert_equal conversations(:architecture_walkthrough), Conversation.ordered.first
  end

  test "a conversation still titled by start! is unnamed and confirms deletion with \"confirm\"" do
    conversation = Conversation.start!

    assert_not conversation.named?
    assert_equal "confirm", conversation.deletion_confirmation
  end

  test "a renamed conversation confirms deletion with its title" do
    conversation = conversations(:architecture_walkthrough)

    assert conversation.named?
    assert_equal "Architecture Overview walkthrough", conversation.deletion_confirmation
  end

  test "deletion confirmation ignores an unsaved title change" do
    conversation = conversations(:architecture_walkthrough)
    conversation.title = "2026-07-24 11:05:32.000000"

    assert_equal "Architecture Overview walkthrough", conversation.deletion_confirmation
  end
end
