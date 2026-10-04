require "application_system_test_case"

class UserCopyCodeBlockTest < ApplicationSystemTestCase
  test "copying a code block from an answer puts its code on the clipboard" do
    conversation = Conversation.create!(title: "Currency helpers")
    conversation.conversation_messages.create!(created_by: :user, content: "How do I show prices?")
    conversation.conversation_messages.create!(created_by: :system, content: <<~MARKDOWN)
      Use the currency helper:

      ```ruby
      <%= number_to_currency(product.price) %>
      ```
    MARKDOWN

    visit conversation_path(conversation)
    # headless Chrome can't read the real clipboard back, so record what the page writes to it
    page.execute_script(<<~JS)
      Object.defineProperty(navigator.clipboard, "writeText", {
        value: (text) => { window.copiedText = text; return Promise.resolve() }
      })
    JS

    within(".code-block") { click_button "Copy code" }

    within(".code-block") { assert_button "Copied" }
    assert_equal "<%= number_to_currency(product.price) %>\n", page.evaluate_script("window.copiedText")
  end
end
