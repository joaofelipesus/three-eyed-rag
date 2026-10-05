# Search indexes (rails-active_search). See config/search.yml for the store each one uses.

# Note file names, for the chat input's "#" autocomplete (Note.search_by_title). Each index's
# document class is nested in its model.
ActiveSearch.define_index(:notes, document_class: "Note::SearchDocument") do
  text :title
end

# Tag names, for the chat input's "@" autocomplete (Tag.search_by_tag_name)
ActiveSearch.define_index(:tags, document_class: "Tag::SearchDocument") do
  text :name
end
