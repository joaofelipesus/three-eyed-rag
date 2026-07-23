module ApplicationHelper
  LIST_ITEM = /\A\s*([-*+]|\d+\.)\s/

  def markdown(text)
    renderer = Redcarpet::Render::HTML.new(escape_html: true)
    parser = Redcarpet::Markdown.new(renderer, fenced_code_blocks: true, tables: true, autolink: true)

    parser.render(force_blank_line_before_lists(text.to_s)).html_safe
  end

  private

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
