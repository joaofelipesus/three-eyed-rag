require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  setup { Tag.find_each(&:reindex) } # fixtures skip the callbacks that fill the search index

  test "search lists tags whose name matches the query, with their note counts" do
    get search_tags_url, params: { q: "rub" }

    assert_response :success
    assert_select ".context-suggestion[data-kind=tag][data-id=?]", tags(:ruby).id.to_s do
      assert_select ".context-suggestion-title mark", "rub"
      assert_select ".context-suggestion-detail", "1 note"
    end
    assert_select ".context-suggestion", count: 1
  end

  test "search leaves out tags already picked as context" do
    get search_tags_url, params: { q: "ruby", exclude: [ tags(:ruby).id ] }

    assert_select ".context-suggestion", count: 0
    assert_select ".context-suggestions-empty"
  end
end
