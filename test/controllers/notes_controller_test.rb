require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  test "should get reload_valut" do
    post reload_valut_notes_url
    assert_response :success
  end

  test "search lists notes whose file name matches the query, with their folders" do
    Note.find_each(&:reindex) # fixtures skip the callbacks that fill the search index

    get search_notes_url, params: { q: "archi" }

    assert_response :success
    assert_select ".context-suggestion[data-kind=note][data-id=?]", notes(:embedded).id.to_s do
      assert_select ".context-suggestion-title mark", "Archi"
      assert_select ".context-suggestion-detail", "projects › three-eyed-rag"
    end
  end

  test "search leaves out notes already picked as context" do
    Note.find_each(&:reindex)

    get search_notes_url, params: { q: "archi", exclude: [ notes(:embedded).id ] }

    assert_select ".context-suggestion", count: 0
    assert_select ".context-suggestions-empty"
  end
end
