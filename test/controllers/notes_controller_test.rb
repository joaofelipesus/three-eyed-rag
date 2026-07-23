require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  test "should get reload_valut" do
    post reload_valut_notes_url
    assert_response :success
  end
end
