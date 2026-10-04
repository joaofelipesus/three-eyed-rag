require "test_helper"

class ConversationMessageTest < ActiveSupport::TestCase
  test "is invalid without content" do
    message = ConversationMessage.new(conversation: conversations(:architecture_walkthrough), created_by: :user, content: nil)

    assert_not message.valid?
    assert_equal [ "can't be blank" ], message.errors[:content]
  end

  test "creating a message touches the parent conversation" do
    conversation = conversations(:architecture_walkthrough)
    previous_updated_at = conversation.updated_at

    travel_to previous_updated_at + 1.hour do
      conversation.conversation_messages.create!(created_by: :user, content: "Another question")
    end

    assert_not_equal previous_updated_at, conversation.reload.updated_at
  end
end
