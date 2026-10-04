# Redcarpet HTML renderer that syntax-highlights fenced code blocks with Rouge, using the
# language named after the opening fence (```ruby). Blocks with no or an unknown language
# are still escaped and wrapped the same way, just without token colors. Every block gets a
# header with its language and a copy button, driven by the code-block Stimulus controller.
class HighlightedCodeRenderer < Redcarpet::Render::HTML
  ERB_TAG = /<%/

  def block_code(code, language)
    language = language.to_s.strip.downcase.presence
    highlighted = Rouge::Formatters::HTML.new.format(lexer_for(language, code).lex(code))

    <<~HTML
      <div class="code-block" data-controller="code-block">
        <div class="code-block-header">
          <span class="code-block-language">#{ERB::Util.html_escape(language)}</span>
          #{copy_button}
        </div>
        <pre class="highlight"><code data-code-block-target="code">#{highlighted}</code></pre>
      </div>
    HTML
  end

  private

  # LLM answers tag ERB view snippets as ```ruby, which the Ruby lexer garbles ("<%=" reads
  # as a %-literal string), so lex those as ERB while keeping the label the model wrote.
  def lexer_for(language, code)
    lexer_class = language && Rouge::Lexer.find(language)
    lexer_class = Rouge::Lexers::ERB if lexer_class == Rouge::Lexers::Ruby && code.match?(ERB_TAG)

    (lexer_class || Rouge::Lexers::PlainText).new
  end

  def copy_button
    icons = ApplicationController.helpers

    <<~HTML.squish
      <button type="button" class="code-block-copy" aria-label="Copy code" title="Copy code"
              data-code-block-target="button" data-action="code-block#copy">
        <span class="code-block-copy-idle">#{icons.lucide_icon("copy", size: 14)}</span>
        <span class="code-block-copy-done" hidden>#{icons.lucide_icon("check", size: 14)} Copied</span>
      </button>
    HTML
  end
end
