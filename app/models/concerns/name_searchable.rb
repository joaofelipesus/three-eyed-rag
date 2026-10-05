# Search over a model's name column through its rails-active_search index (config/search.rb),
# whose trigram tokenizer matches any part of a word, ignoring case and accents. Used by the chat
# input's "#" (notes) and "@" (tags) autocompletes.
module NameSearchable
  extend ActiveSupport::Concern

  MIN_LENGTH = 3 # trigrams can't match anything shorter

  class_methods do
    # records whose name matches the query, best match first: every word of the query has to
    # appear, in any order. Queries under 3 characters fall back to a name prefix.
    def search_by_name(column, query, limit: 8, exclude: [])
      query = query.to_s.strip
      excluded_ids = Array(exclude).map(&:to_i)

      if query.length < MIN_LENGTH
        return where(arel_table[column].matches("#{sanitize_sql_like(query)}%", "\\"))
          .where.not(id: excluded_ids).order(column).limit(limit).to_a
      end

      terms = query.split.select { |term| term.length >= MIN_LENGTH }
      search(terms.join(" "), fields: [ column ]).limit(limit + excluded_ids.size).results.to_a
        .reject { |record| excluded_ids.include?(record.id) }.first(limit)
    end
  end
end
