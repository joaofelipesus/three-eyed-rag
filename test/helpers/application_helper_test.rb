require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "markdown highlights a fenced code block in the language after the fence" do
    html = markdown("```ruby\ndef greet\n  puts \"hi\"\nend\n```")

    assert_includes html, %(<span class="code-block-language">ruby</span>)
    assert_includes html, %(<span class="k">def</span>)
    assert_includes html, %(<span class="nb">puts</span>)
    assert_includes html, %(<span class="s2">"hi"</span>)
  end

  test "markdown escapes HTML inside a highlighted code block" do
    html = markdown("```erb\n<%= tag.script %>\n```")

    assert_includes html, %(<span class="cp">&lt;%=</span>)
    assert_not_includes html, "<%="
  end

  test "markdown renders a fence without a known language as escaped plain code" do
    html = markdown("```\n<b>bold</b>\n```\n\n```not-a-language\nx\n```")

    assert_includes html, "&lt;b&gt;bold&lt;/b&gt;"
    assert_includes html, %(<span class="code-block-language">not-a-language</span>)
    assert_includes html, %(<code data-code-block-target="code">&lt;b&gt;bold&lt;/b&gt;\n</code>)
    assert_includes html, %(<code data-code-block-target="code">x\n</code>)
  end

  test "markdown turns code squeezed onto a one-line fence into a highlighted block" do
    html = markdown("- Use a decimal column:\n ```ruby add_column :products, :price, :decimal ```\n Then it's exact.")

    assert_includes html, %(<span class="code-block-language">ruby</span>)
    assert_includes html, %(<span class="ss">:products</span>)
    assert_includes html, "<p>Then it&#39;s exact.</p>"
  end

  test "markdown turns code written after an opening fence into a highlighted block" do
    html = markdown("Example:\n ```ruby puts 1\n ```\n After.")

    assert_includes html, %(<span class="nb">puts</span>)
    assert_includes html, "<p>After.</p>"
  end

  test "markdown highlights ERB tags in a block tagged as ruby" do
    html = markdown("```ruby\n<%= number_to_currency(product.price) %>\n```")

    assert_includes html, %(<span class="code-block-language">ruby</span>)
    assert_includes html, %(<span class="cp">&lt;%=</span>)
    assert_includes html, %(<span class="n">number_to_currency</span>)
  end

  test "markdown gives every code block a copy button" do
    html = markdown("```ruby\nputs 1\n```\n\n```\nplain\n```")

    assert_equal 2, html.scan(%(data-action="code-block#copy")).size
  end

  test "markdown renders the answer's Sources list as note cards" do
    render html: markdown("Answer.\n\n**Sources:**\n\n- `/usr/src/app/obsidian_vault/Notes/Rails/helpers/number_to_currency.md`")

    assert_select "p", "Answer."
    assert_select "details.answer-sources[open] > summary .answer-sources-count", "1"
    assert_select ".answer-source[title=?]", "/usr/src/app/obsidian_vault/Notes/Rails/helpers/number_to_currency.md" do
      assert_select ".answer-source-name", "number_to_currency"
      assert_select ".answer-source-folders", "Notes › Rails › helpers"
    end
    assert_select "code", count: 0
  end

  test "markdown turns a fence opened after text on a list item into a highlighted block" do
    html = markdown("- **Example**: ```Ruby Product.new.tap do |product|\n product.save\n end ```\n- **Next**: more text")

    assert_includes html, "<strong>Example</strong>:"
    assert_includes html, %(<span class="code-block-language">ruby</span>)
    assert_includes html, %(<span class="k">do</span>)
    assert_includes html, "<strong>Next</strong>: more text"
  end

  test "markdown doesn't turn a closing fence on its own line into an empty block" do
    html = markdown("Like in: ```ruby words.tally.tap { |r| puts r }\n ```\n\nAfter.")

    assert_equal 1, html.scan(%(class="code-block")).size
    assert_includes html, %(<span class="nf">tally</span>)
    assert_includes html, "<p>After.</p>"
  end

  test "markdown keeps text written after a closing fence on the same line" do
    html = markdown("```ruby puts 1``` and that's it")

    assert_includes html, %(<span class="nb">puts</span>)
    assert_includes html, "<p>and that&#39;s it</p>"
  end
end
