require "application_system_test_case"

class UserStartConversationTest < ApplicationSystemTestCase
  test "sending a message from the home starts a new conversation" do
    # skip Ollama: the app server runs in this process, so the stub also applies to its request
    Note.expects(:chat).with("hello there", anything).returns("Hi! How can I help?")

    visit root_path
    fill_in placeholder: "Ask something about your notes...", with: "hello there"
    click_button "Send"

    assert_selector ".chat-message-question", text: "hello there"
    assert_selector ".chat-message-answer", text: "Hi! How can I help?"

    conversation = Conversation.order(:created_at).last
    assert_current_path conversation_path(conversation)
    assert_equal [ [ "user", "hello there" ], [ "system", "Hi! How can I help?" ] ],
                 conversation.conversation_messages.order(:id).pluck(:created_by, :content)

    visit root_path

    within "#sidebar_conversations_list" do
      assert_link conversation.title, href: conversation_path(conversation)
    end
  end
end
