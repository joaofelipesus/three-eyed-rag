require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  test "index lists conversations ordered by most recently updated" do
    conversations(:vault_ingestion_debug).touch

    get conversations_url

    assert_response :success
    assert_select "a", conversations(:vault_ingestion_debug).title
    assert_select "a", conversations(:architecture_walkthrough).title
  end

  test "show displays the conversation's messages" do
    conversation = conversations(:architecture_walkthrough)

    get conversation_url(conversation)

    assert_response :success
    assert_select ".chat-message-question", text: conversation_messages(:architecture_question).content
  end

  test "show renders a fresh conversation with no messages" do
    conversation = Conversation.create!(title: "Empty conversation")

    get conversation_url(conversation)

    assert_response :success
    assert_select ".chat-message-question", count: 0
  end
end
