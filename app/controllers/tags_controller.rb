class TagsController < ApplicationController
  # suggestions for the chat input's "@" autocomplete, matched by tag name
  def search
    @query = params[:q].to_s.strip
    @tags = Tag.search_by_tag_name(@query, exclude: params[:exclude])

    render partial: "tags/search_results", locals: { tags: @tags, query: @query }
  end
end
