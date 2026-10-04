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

  test "update renames the conversation and streams the title and sidebar entry" do
    conversation = conversations(:architecture_walkthrough)

    patch conversation_url(conversation), params: { conversation: { title: "Renamed conversation" } }

    assert_response :success
    assert_equal "Renamed conversation", conversation.reload.title
    assert_select "turbo-stream[action=replace][target=conversation_title]"
    assert_select "turbo-stream[action=replace][target=conversation_#{conversation.id}]"
  end

  test "update rejects a blank title and re-renders the form with an error" do
    conversation = conversations(:architecture_walkthrough)

    patch conversation_url(conversation), params: { conversation: { title: "" } }

    assert_response :unprocessable_entity
    assert_equal "Architecture Overview walkthrough", conversation.reload.title
    assert_select "turbo-stream[action=replace][target=conversation_title]"
  end

  test "destroy deletes a named conversation and its messages when confirmed with its title" do
    conversation = conversations(:architecture_walkthrough)

    assert_difference -> { Conversation.count } => -1, -> { ConversationMessage.count } => -conversation.conversation_messages.count do
      delete conversation_url(conversation), params: { confirmation: "Architecture Overview walkthrough" }
    end

    assert_redirected_to root_url
    assert_response :see_other
  end

  test "destroy deletes an unnamed conversation when confirmed with \"confirm\"" do
    conversation = Conversation.start!

    assert_difference -> { Conversation.count }, -1 do
      delete conversation_url(conversation), params: { confirmation: "confirm" }
    end

    assert_redirected_to root_url
  end

  test "destroy keeps the conversation when the confirmation doesn't match" do
    conversation = conversations(:architecture_walkthrough)

    assert_no_difference -> { Conversation.count } do
      delete conversation_url(conversation), params: { confirmation: "confirm" }
    end

    assert_redirected_to conversation_url(conversation)
  end
end
