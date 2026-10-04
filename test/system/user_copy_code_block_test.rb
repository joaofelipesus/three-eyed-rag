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
    page.driver.browser.command("Browser.grantPermissions", origin: page.server.base_url,
                                                            permissions: %w[clipboardReadWrite clipboardSanitizedWrite])
    within(".code-block") { click_button "Copy code" }

    within(".code-block") { assert_button "Copied" }
    assert_equal "<%= number_to_currency(product.price) %>\n", page.evaluate_async_script(<<~JS)
      navigator.clipboard.readText().then(arguments[0])
    JS
  end
end
