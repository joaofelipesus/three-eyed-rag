require "application_system_test_case"

class UserAddContextTest < ApplicationSystemTestCase
  PLACEHOLDER = "Ask something about your notes... (# adds a note, @ a tag as context)"

  # fixtures skip the callbacks that fill the search indexes
  setup do
    Note.find_each(&:reindex)
    Tag.find_each(&:reindex)
  end

  test "typing # finds a note by a multi-word name and sends it as context with the question" do
    Note.expects(:chat).with("explain this", anything, context_notes: [ notes(:embedded) ], context_tags: []).returns("It's the pipeline.")

    visit root_path
    question = find_field(placeholder: PLACEHOLDER)
    question.send_keys "explain this #overview archi"

    within("#context_suggestions") { assert_selector ".context-suggestion", text: "Architecture Overview" }
    question.send_keys :enter

    within(".chat-context") { assert_text "Architecture Overview" }
    assert_no_selector "#context_suggestions .context-suggestion"
    assert_equal "explain this ", question.value

    click_button "Send"

    assert_selector ".chat-message-answer", text: "It's the pipeline."
  end

  test "typing @ finds a tag and sends it as context with the question" do
    Note.expects(:chat).with("what about ruby", anything, context_notes: [], context_tags: [ tags(:ruby) ]).returns("Ruby notes.")

    visit root_path
    question = find_field(placeholder: PLACEHOLDER)
    question.send_keys "what about ruby @rub"

    within("#context_suggestions") { assert_selector ".context-suggestion", text: "ruby" }
    question.send_keys :enter

    within(".chat-context") { assert_text "ruby" }
    click_button "Send"

    assert_selector ".chat-message-answer", text: "Ruby notes."
  end

  test "a note added as context can be removed" do
    visit root_path
    question = find_field(placeholder: PLACEHOLDER)
    question.send_keys "#archi"
    within("#context_suggestions") { assert_selector ".context-suggestion", text: "Architecture Overview" }
    question.send_keys :enter

    click_button "Remove Architecture Overview from context"

    assert_no_selector ".chat-context"
  end

  test "escape closes the suggestions so the message can go on after the #" do
    visit root_path
    question = find_field(placeholder: PLACEHOLDER)
    question.send_keys "#archi"
    within("#context_suggestions") { assert_selector ".context-suggestion" }

    question.send_keys :escape
    question.send_keys " and more"

    assert_no_selector "#context_suggestions .context-suggestion"
    assert_equal "#archi and more", question.value
  end
end
