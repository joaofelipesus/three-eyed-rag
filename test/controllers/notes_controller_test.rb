require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  test "should get reload_valut" do
    get notes_reload_valut_url
    assert_response :success
  end
end
