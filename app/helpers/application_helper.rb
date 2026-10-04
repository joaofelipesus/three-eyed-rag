module ApplicationHelper
  LIST_ITEM = /\A\s*([-*+]|\d+\.)\s/
  FENCE = "```"
  # the language right after an opening fence ("```ruby"), if any
  FENCE_LANGUAGE = /\A[A-Za-z][\w+#.-]*(?=\s|\z|```)/

  def markdown(text)
    renderer = HighlightedCodeRenderer.new(escape_html: true)
    parser = Redcarpet::Markdown.new(renderer, fenced_code_blocks: true, tables: true, autolink: true)

    body, source_paths = Note.split_sources(text.to_s)
    html = parser.render(force_blank_line_before_lists(normalize_code_fences(body))).html_safe
    return html if source_paths.empty?

    html + render("conversations/sources", sources: source_notes(source_paths))
  end

  private

  # the cited notes in citation order; a note removed from the vault since is described from its path alone
  def source_notes(paths)
    notes_by_path = Note.where(path: paths).index_by(&:path)
    paths.map { |path| notes_by_path[path] || Note.new(path: path, title: File.basename(path, ".md")) }
  end

  # LLM output often squeezes a fenced code block onto other lines: code after the opening fence
  # ("```ruby puts 1"), the closing fence after the code ("end ```"), or the opening fence after
  # text ("- **Example**: ```ruby ..."), sometimes indented under a list item. Redcarpet then reads
  # it as inline code, or a lone closing fence as the start of an endless block, so put every
  # fence on its own unindented line, with blank lines around the block, and any text before an
  # opening fence or after a closing one on lines of its own.
  def normalize_code_fences(text)
    in_fence = false
    output = []

    text.split("\n").each do |line|
      rest = line

      while rest
        fence_at = rest.index(FENCE)
        unless fence_at
          output << rest
          break
        end

        before = rest[0...fence_at].rstrip
        after = rest[(fence_at + FENCE.length)..]

        if in_fence
          output.push(*[ before.presence, FENCE, "" ].compact)
        else
          language = after[FENCE_LANGUAGE].to_s
          after = after.delete_prefix(language)
          output.push(*[ before.strip.presence && before, "", "#{FENCE}#{language}" ].compact)
        end

        in_fence = !in_fence
        rest = after.strip.presence
      end
    end

    output.join("\n")
  end

  # Unlike CommonMark, Redcarpet won't let a list interrupt or be interrupted by a
  # paragraph: a "- " line placed directly under a heading/label, or a label placed
  # directly under a list, with no blank line between them, gets swallowed as plain
  # text instead of becoming its own block. LLM output doesn't reliably leave that
  # blank line, so insert it ourselves at every such transition.
  def force_blank_line_before_lists(text)
    lines = text.split("\n")

    lines.each_with_index.flat_map do |line, index|
      previous_line = lines[index - 1]
      crosses_list_boundary = index.positive? && previous_line.present? && line.present? &&
        line.match?(LIST_ITEM) != previous_line.match?(LIST_ITEM)

      crosses_list_boundary ? [ "", line ] : [ line ]
    end.join("\n")
  end
end
