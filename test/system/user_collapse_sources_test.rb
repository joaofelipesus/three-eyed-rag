require "application_system_test_case"

class UserCollapseSourcesTest < ApplicationSystemTestCase
  test "the sources under an answer can be collapsed and expanded" do
    conversation = Conversation.create!(title: "Currency helpers")
    conversation.conversation_messages.create!(created_by: :user, content: "How do I show prices?")
    conversation.conversation_messages.create!(created_by: :system, content: <<~MARKDOWN)
      Use `number_to_currency`.

      **Sources:**

      - `/usr/src/app/obsidian_vault/Notes/Rails/helpers/number_to_currency.md`
    MARKDOWN

    visit conversation_path(conversation)
    assert_selector ".answer-source", text: "number_to_currency"

    find("summary", text: "SOURCES").click
    assert_no_selector ".answer-source"

    find("summary", text: "SOURCES").click
    assert_selector ".answer-source", text: "number_to_currency"
  end
end
