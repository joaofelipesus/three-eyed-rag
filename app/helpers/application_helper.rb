module ApplicationHelper
  def markdown(text)
    renderer = Redcarpet::Render::HTML.new(escape_html: true, hard_wrap: true)
    parser = Redcarpet::Markdown.new(renderer, fenced_code_blocks: true, tables: true, autolink: true)

    parser.render(text.to_s).html_safe
  end
end
