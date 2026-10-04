require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  test "shows an empty chat ready for a new question" do
    visit root_path

    assert_field placeholder: "Ask something about your notes..."
    assert_button "Send"
  end
end
