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
end
