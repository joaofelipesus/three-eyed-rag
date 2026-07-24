require "test_helper"

class ConversationMessagesControllerTest < ActionDispatch::IntegrationTest
  test "starts a new conversation titled with the current timestamp on the first message" do
    Note.stubs(:chat).returns("Hi there.")

    travel_to Time.zone.local(2026, 7, 24, 11, 5, 32) do
      assert_difference "Conversation.count", 1 do
        assert_difference "ConversationMessage.count", 2 do
          post conversation_messages_url, params: { content: "Hello" }
        end
      end
    end

    conversation = Conversation.find_by!(title: "2026-07-24 11:05:32.000000")
    assert_equal [ "user", "system" ], conversation.conversation_messages.order(:created_at).pluck(:created_by)
  end

  test "continues an existing conversation without starting a new one" do
    Note.stubs(:chat).returns("Sure, here's more.")
    conversation = conversations(:architecture_walkthrough)

    assert_no_difference "Conversation.count" do
      assert_difference "ConversationMessage.count", 2 do
        post conversation_messages_url, params: { content: "Tell me more", conversation_id: conversation.id }
      end
    end
  end
end
