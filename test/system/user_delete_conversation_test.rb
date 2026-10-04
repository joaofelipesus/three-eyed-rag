require "application_system_test_case"

class UserDeleteConversationTest < ApplicationSystemTestCase
  test "deleting a named conversation requires typing its title" do
    conversation = conversations(:architecture_walkthrough)

    visit conversation_path(conversation)
    click_button "Delete conversation"

    within "dialog[open]" do
      assert_text "Type #{conversation.title} to confirm"

      fill_in "Type #{conversation.title} to confirm", with: "confirm"
      assert_button "Delete conversation", disabled: true

      fill_in "Type #{conversation.title} to confirm", with: conversation.title
      click_button "Delete conversation"
    end

    assert_current_path root_path
    assert_no_selector "#sidebar_conversations_list", text: conversation.title
    assert_not Conversation.exists?(conversation.id)
  end

  test "deleting an unnamed conversation requires typing confirm" do
    conversation = Conversation.start!

    visit conversation_path(conversation)
    click_button "Delete conversation"

    within "dialog[open]" do
      fill_in "Type confirm to confirm", with: "confirm"
      click_button "Delete conversation"
    end

    assert_current_path root_path
    assert_not Conversation.exists?(conversation.id)
  end

  test "cancel closes the dialog and keeps the conversation" do
    conversation = conversations(:architecture_walkthrough)

    visit conversation_path(conversation)
    click_button "Delete conversation"
    within("dialog[open]") { click_button "Cancel" }

    assert_no_selector "dialog[open]"
    assert Conversation.exists?(conversation.id)
  end
end
