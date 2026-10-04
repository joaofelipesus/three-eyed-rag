module ApplicationHelper
  LIST_ITEM = /\A\s*([-*+]|\d+\.)\s/
  # an opening fence, its optional language, and anything the model wrote after it on the same line
  OPENING_FENCE = /\A\s*```(?:([A-Za-z][\w+#.-]*)(?=\s|\z))?\s*(.*)\z/
  CLOSING_FENCE = /\A(.*?)\s*```\s*\z/

  def markdown(text)
    renderer = HighlightedCodeRenderer.new(escape_html: true)
    parser = Redcarpet::Markdown.new(renderer, fenced_code_blocks: true, tables: true, autolink: true)

    parser.render(force_blank_line_before_lists(normalize_code_fences(text.to_s))).html_safe
  end

  private

  # LLM output often squeezes a fenced code block onto the fence lines ("```ruby puts 1```",
  # or "```ruby puts 1" with the closing fence below), sometimes indented under a list item.
  # Redcarpet then reads it as inline code and it never gets highlighted, so rewrite every
  # fence onto its own unindented line, with blank lines around the block.
  def normalize_code_fences(text)
    in_fence = false

    text.split("\n").flat_map do |line|
      if in_fence
        next line unless (closing = line.match(CLOSING_FENCE))

        in_fence = false
        [ closing[1].presence, "```", "" ].compact
      elsif (opening = line.match(OPENING_FENCE))
        language, rest = opening[1], opening[2]
        closing = rest.match(CLOSING_FENCE)
        in_fence = closing.nil?

        code = closing ? closing[1] : rest
        [ "", "```#{language}", code.presence, *("```" if closing), *("" if closing) ].compact
      else
        line
      end
    end.join("\n")
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
