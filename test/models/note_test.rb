require "test_helper"
require "tmpdir"

class NoteTest < ActiveSupport::TestCase
  test "relations" do
    note = Note.new

    assert_respond_to note, :note_embedding
    assert_respond_to note, :note_tags
  end

  test "fixture note is valid" do
    assert notes(:embedded).valid?
  end

  test "is invalid without a title or path and reports the errors" do
    note = Note.new(title: nil, path: nil)

    assert_not note.valid?
    assert_equal [ "can't be blank" ], note.errors[:title]
    assert_equal [ "can't be blank" ], note.errors[:path]
  end

  test "generate_embedding splits the note content into sections by heading and embeds each one" do
    note = notes(:pending_embedding)
    note.update!(content: <<~MARKDOWN)
      # Title

      Intro paragraph.

      ## First heading

      First body.

      #### Not a split point

      Still part of first heading.

      ### Second heading

      Second body.
    MARKDOWN

    note.define_singleton_method(:fetch_embedding) { |_text| Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1) }

    assert_difference "NoteSection.count", 3 do
      note.generate_embedding
    end

    sections = note.note_sections.order(:id)

    assert_equal "# Title\n\nIntro paragraph.", sections[0].content
    assert_includes sections[1].content, "## First heading"
    assert_includes sections[1].content, "#### Not a split point"
    assert_equal "### Second heading\n\nSecond body.", sections[2].content

    assert sections.all? { |section| section.note_section_embedding.present? }
    assert note.reload.last_embeded_at.present?
  end

  test "generate_embedding attaches images referenced with Obsidian's embed syntax" do
    Dir.mktmpdir do |dir|
      vault_dir = File.join(dir, "obsidian_vault")
      FileUtils.mkdir_p(File.join(vault_dir, "attachments"))
      File.write(File.join(vault_dir, "attachments", "Screenshot 2026-07-08 at 11.06.19.png"), "fake image data")
      File.write(File.join(vault_dir, "attachments", "diagram.pdf"), "not an image")

      Rails.stubs(:root).returns(Pathname.new(dir))

      note = notes(:pending_embedding)
      note.define_singleton_method(:fetch_embedding) { |_text| Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1) }
      note.update!(content: <<~MARKDOWN)
        # Title

        See the screenshot below.

        ![[Screenshot 2026-07-08 at 11.06.19.png]]

        Not an image: ![[diagram.pdf]]
      MARKDOWN

      note.generate_embedding

      section = note.note_sections.sole
      assert_equal 1, section.images.count
      assert_equal "Screenshot 2026-07-08 at 11.06.19.png", section.images.first.filename.to_s
    end
  end

  test "generate_embedding ignores related notes and tags sections" do
    note = notes(:pending_embedding)
    note.update!(content: <<~MARKDOWN)
      # Title

      Body.

      ### Related notes:

      - [[Other note]]

      ### Tags: #revelo
    MARKDOWN

    note.define_singleton_method(:fetch_embedding) { |_text| Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1) }

    assert_difference "NoteSection.count", 1 do
      note.generate_embedding
    end

    assert_equal "# Title\n\nBody.", note.note_sections.sole.content
  end

  test "generate_embedding drops sections that are no longer present in the content" do
    note = notes(:pending_embedding)
    note.define_singleton_method(:fetch_embedding) { |_text| Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1) }

    note.update!(content: "# Only heading\n\nBody.")
    note.generate_embedding
    assert_equal 1, note.note_sections.count

    note.update!(content: "# Only heading\n\nBody.\n\n## Another\n\nMore.")
    note.generate_embedding
    assert_equal 2, note.note_sections.count
  end

  test "generate_embedding reuses sections whose content is unchanged instead of re-embedding them" do
    note = notes(:pending_embedding)
    embed_calls = []
    note.define_singleton_method(:fetch_embedding) do |text|
      embed_calls << text
      Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1)
    end

    note.update!(content: "# Only heading\n\nBody.")
    note.generate_embedding
    unchanged_section = note.note_sections.sole

    note.update!(content: "# Only heading\n\nBody.\n\n## Another\n\nMore.")
    note.generate_embedding

    assert_equal 1, embed_calls.count(unchanged_section.content)
    assert_equal unchanged_section.id, note.note_sections.find_by(content: unchanged_section.content).id
  end

  test "vault_documents_count counts markdown files, excluding excalidraw files" do
    Dir.mktmpdir do |dir|
      vault_dir = File.join(dir, "obsidian_vault")
      FileUtils.mkdir_p(File.join(vault_dir, "nested"))

      File.write(File.join(vault_dir, "note1.md"), "# Note 1")
      File.write(File.join(vault_dir, "nested", "note2.md"), "# Note 2")
      File.write(File.join(vault_dir, "diagram.excalidraw.md"), "{}")
      File.write(File.join(vault_dir, "note3.txt"), "not markdown")

      Rails.stubs(:root).returns(Pathname.new(dir))

      assert_equal 2, Note.vault_documents_count
    end
  end

  test "tag_names reads the tags listed on a Tags line or heading" do
    assert_equal %w[ubuntu setup], Note.new(content: "Tags: #ubuntu #setup ").tag_names
    assert_equal %w[algoritimos ruby], Note.new(content: "Body.\n\n### Tags: #algoritimos #ruby\n").tag_names
    assert_equal %w[ruby rails web], Note.new(content: "### Tags:\n#ruby #rails\n#web\n\nMore text #notatag\n").tag_names
  end

  test "tag_names ignores # that isn't in a Tags marker" do
    assert_empty Note.new(content: "# Title\n\nWritten in C# with a #hashtag in prose.").tag_names
  end

  test "process_vault tags an unchanged note whose tags were never read, without re-embedding it" do
    Dir.mktmpdir do |dir|
      vault_dir = File.join(dir, "obsidian_vault")
      FileUtils.mkdir_p(vault_dir)
      content = "# Title\n\nBody.\n\n### Tags: #ruby #newtag\n"
      path = File.join(vault_dir, "note.md")
      File.write(path, content)
      note = Note.create!(path: path, title: "note", content: content, checksum: Digest::SHA256.hexdigest(content))

      Rails.stubs(:root).returns(Pathname.new(dir))
      Note.any_instance.expects(:generate_embedding).never

      Note.process_vault

      assert_equal %w[newtag ruby], note.reload.tags.pluck(:name).sort
    end
  end

  test "process_vault drops tags a note no longer lists" do
    Dir.mktmpdir do |dir|
      vault_dir = File.join(dir, "obsidian_vault")
      FileUtils.mkdir_p(vault_dir)
      content = "# Title\n\n### Tags: #rails\n"
      path = File.join(vault_dir, "note.md")
      File.write(path, content)
      note = Note.create!(path: path, title: "note", content: content, checksum: Digest::SHA256.hexdigest(content))
      note.tags << tags(:ruby)

      Rails.stubs(:root).returns(Pathname.new(dir))
      Note.process_vault

      assert_equal [ "rails" ], note.reload.tags.pluck(:name)
    end
  end

  test "process_vault skips re-embedding a note whose checksum is unchanged and keeps its tags" do
    Dir.mktmpdir do |dir|
      vault_dir = File.join(dir, "obsidian_vault")
      FileUtils.mkdir_p(vault_dir)

      content = <<~MARKDOWN
        # Title

        Body.

        ### Tags: #unchanged
      MARKDOWN
      File.write(File.join(vault_dir, "note.md"), content)

      Rails.stubs(:root).returns(Pathname.new(dir))
      Note.any_instance.stubs(:fetch_embedding).returns(Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1))

      Note.process_vault

      note = Note.find_by(path: File.join(vault_dir, "note.md"))
      assert note.processed?
      assert_equal Digest::SHA256.hexdigest(content), note.checksum
      assert_equal [ "unchanged" ], note.tags.pluck(:name)
      section_ids = note.note_sections.pluck(:id)
      tag_count = NoteTag.count

      Note.any_instance.expects(:generate_embedding).never

      assert_no_difference [ "Note.count", "NoteTag.count" ] do
        Note.process_vault
      end

      note.reload
      assert note.processed?
      assert_equal section_ids, note.note_sections.pluck(:id)
      assert_equal tag_count, NoteTag.count
    end
  end

  test "chat streams the model's response chunks to the given sse object and returns the answer with a deterministic sources section" do
    Note.any_instance.stubs(:fetch_embedding).returns(Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1))

    requested_body = nil
    stream_lines = [
      { message: { content: "Formatted answer." }, done: false }.to_json + "\n",
      { message: { content: "\nSOURCES: 1, 2" }, done: false }.to_json + "\n",
      { message: { content: "" }, done: true }.to_json + "\n"
    ]

    fake_response = stub("response")
    fake_response.stubs(:read_body).multiple_yields(*stream_lines.map { |line| [ line ] })

    expectation = Net::HTTP.any_instance.stubs(:request)
    expectation.with do |request|
      requested_body = JSON.parse(request.body)
      true
    end
    expectation.yields(fake_response)

    written = []
    sse = Object.new
    sse.define_singleton_method(:write) { |payload, event: nil| written << { payload: payload, event: event } }

    answer = Note.chat("What is the architecture?", sse)

    # both fixture sections belong to the same note, so the sources list dedupes to one path
    assert_equal "Formatted answer.\n\n**Sources:**\n\n- `#{notes(:embedded).path}`", answer
    assert_equal "qwen3:8b", requested_body["model"]
    assert requested_body["stream"]

    system_message, user_message = requested_body["messages"].map { |message| message["content"] }
    assert_includes system_message, "Evaluate which of the note sections are actually related"
    assert_includes user_message, "What is the architecture?"
    assert_includes user_message, "Source: #{notes(:embedded).path}"
    assert_includes user_message, note_sections(:first).content

    assert_equal [
      { payload: { content: "Formatted answer." }, event: "chunk" },
      { payload: { content: "\nSOURCES: 1, 2" }, event: "chunk" }
    ], written
  end

  test "chat falls back to listing every retrieved section when the model omits the sources directive" do
    Note.any_instance.stubs(:fetch_embedding).returns(Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1))

    stream_lines = [
      { message: { content: "Formatted answer." }, done: false }.to_json + "\n",
      { message: { content: "" }, done: true }.to_json + "\n"
    ]

    fake_response = stub("response")
    fake_response.stubs(:read_body).multiple_yields(*stream_lines.map { |line| [ line ] })
    Net::HTTP.any_instance.stubs(:request).yields(fake_response)

    sse = Object.new
    sse.define_singleton_method(:write) { |payload, event: nil| nil }

    answer = Note.chat("What is the architecture?", sse)

    assert_equal "Formatted answer.\n\n**Sources:**\n\n- `#{notes(:embedded).path}`", answer
  end

  test "chat renders images the vision model judges relevant, and excludes the ones it doesn't" do
    note_sections(:first).images.attach(
      io: File.open(Rails.root.join("test/fixtures/files/screenshot.png")),
      filename: "relevant.png",
      content_type: "image/png"
    )
    note_sections(:second).images.attach(
      io: File.open(Rails.root.join("test/fixtures/files/unrelated.png")),
      filename: "irrelevant.png",
      content_type: "image/png"
    )

    Note.any_instance.stubs(:fetch_embedding).returns(Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1))

    stream_lines = [
      { message: { content: "Formatted answer.\nSOURCES: 1, 2" }, done: false }.to_json + "\n",
      { message: { content: "" }, done: true }.to_json + "\n"
    ]
    fake_stream_response = stub("stream_response")
    fake_stream_response.stubs(:read_body).multiple_yields(*stream_lines.map { |line| [ line ] })

    relevant_image_base64 = Base64.strict_encode64(File.binread(Rails.root.join("test/fixtures/files/screenshot.png")))

    Net::HTTP.any_instance.stubs(:request)
      .with { |request| JSON.parse(request.body)["model"] == "qwen3:8b" }
      .yields(fake_stream_response)

    Net::HTTP.any_instance.stubs(:request)
      .with { |request| JSON.parse(request.body).dig("messages", 0, "images", 0) == relevant_image_base64 }
      .returns(stub(body: { message: { content: "YES" } }.to_json))

    Net::HTTP.any_instance.stubs(:request)
      .with do |request|
        body = JSON.parse(request.body)
        body["model"] == "qwen2.5vl:7b" && body.dig("messages", 0, "images", 0) != relevant_image_base64
      end
      .returns(stub(body: { message: { content: "NO" } }.to_json))

    sse = Object.new
    sse.define_singleton_method(:write) { |payload, event: nil| nil }

    answer = Note.chat("What is the architecture?", sse)

    image_url = Rails.application.routes.url_helpers.rails_blob_path(
      note_sections(:first).images.first, only_path: true
    )

    assert_equal <<~ANSWER.strip, answer
      Formatted answer.

      ![relevant.png](#{image_url})

      **Sources:**

      - `#{notes(:embedded).path}`
    ANSWER
  end

  test "chat omits the sources section when the model reports none of the sections were relevant" do
    Note.any_instance.stubs(:fetch_embedding).returns(Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1))

    stream_lines = [
      { message: { content: "Sorry, I couldn't find anything relevant.\nSOURCES: none" }, done: false }.to_json + "\n",
      { message: { content: "" }, done: true }.to_json + "\n"
    ]

    fake_response = stub("response")
    fake_response.stubs(:read_body).multiple_yields(*stream_lines.map { |line| [ line ] })
    Net::HTTP.any_instance.stubs(:request).yields(fake_response)

    sse = Object.new
    sse.define_singleton_method(:write) { |payload, event: nil| nil }

    answer = Note.chat("What is the architecture?", sse)

    assert_equal "Sorry, I couldn't find anything relevant.", answer
  end

  test "split_sources separates the Sources list appended to an answer" do
    answer = "Formatted answer.\n\n**Sources:**\n\n- `/vault/a.md`\n- `/vault/b.md`"

    assert_equal [ "Formatted answer.", [ "/vault/a.md", "/vault/b.md" ] ], Note.split_sources(answer)
  end

  test "split_sources leaves an answer without a Sources list whole" do
    assert_equal [ "Just an answer.", [] ], Note.split_sources("Just an answer.")
  end

  test "split_sources leaves a Sources heading followed by other content in the answer" do
    answer = "**Sources:** are cited inline.\n\nMore text."

    assert_equal [ answer, [] ], Note.split_sources(answer)
  end

  test "folders are the path from the vault root down to the note" do
    note = Note.new(path: "/usr/src/app/obsidian_vault/Notes/Rails/Rails Views/helpers/number_to_currency.md")

    assert_equal [ "Notes", "Rails", "Rails Views", "helpers" ], note.folders
  end

  test "a note at the vault root has no folders" do
    assert_empty Note.new(path: "/usr/src/app/obsidian_vault/Inbox.md").folders
  end

  test "search_by_title matches part of a word in the file name, ignoring case and accents" do
    Note.find_each(&:reindex) # fixtures skip the callbacks that fill the search index
    note = Note.create!(title: "Definição de campo decimal rails", path: "rails/Definição de campo decimal rails.md")

    assert_equal [ note ], Note.search_by_title("DEFINICAO")
    assert_includes Note.search_by_title("archi"), notes(:embedded)
  end

  test "search_by_title finds multi-word names from words typed in any order" do
    note = Note.create!(title: "Definição de campo decimal rails", path: "rails/Definição de campo decimal rails.md")
    Note.create!(title: "Rails views", path: "rails/Rails views.md")

    assert_equal [ note ], Note.search_by_title("decimal rails")
    assert_equal [ note ], Note.search_by_title("rails  campo decim")
  end

  test "search_by_title doesn't match on the folders in the path" do
    Note.find_each(&:reindex)
    assert_empty Note.search_by_title("three-eyed-rag")
  end

  test "search_by_title treats underscores as literal characters" do
    note = Note.create!(title: "number_to_currency", path: "rails/number_to_currency.md")
    Note.create!(title: "numberXtoXcurrency", path: "rails/numberXtoXcurrency.md")

    assert_equal [ note ], Note.search_by_title("number_to")
  end

  test "search_by_title matches a name prefix for queries too short to search" do
    assert_equal [ notes(:pending_embedding) ], Note.search_by_title("20")
  end

  test "search_by_title leaves out excluded notes" do
    Note.find_each(&:reindex)
    assert_empty Note.search_by_title("architecture", exclude: [ notes(:embedded).id.to_s ])
  end

  test "chat sends picked context notes whole as primary context, numbered before the retrieved sections" do
    Note.any_instance.stubs(:fetch_embedding).returns(Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1))
    context_note = notes(:pending_embedding)

    requested_body = nil
    stream_lines = [
      { message: { content: "Answer.\nSOURCES: 1" }, done: false }.to_json + "\n",
      { message: { content: "" }, done: true }.to_json + "\n"
    ]
    fake_response = stub("response")
    fake_response.stubs(:read_body).multiple_yields(*stream_lines.map { |line| [ line ] })
    expectation = Net::HTTP.any_instance.stubs(:request)
    expectation.with { |request| requested_body = JSON.parse(request.body) }
    expectation.yields(fake_response)

    sse = Object.new
    sse.define_singleton_method(:write) { |payload, event: nil| nil }

    answer = Note.chat("What did I do today?", sse, context_notes: [ context_note ])

    system_message, user_message = requested_body["messages"].map { |message| message["content"] }
    assert_includes system_message, "Primary context"
    assert_includes user_message, "Primary context (picked by the user for this message):\n\n[1] Source: #{context_note.path}\n#{context_note.content}"
    assert_includes user_message, "[2] Source: #{notes(:embedded).path}"
    assert_operator user_message.index("Primary context"), :<, user_message.index("Note sections:")
    assert_equal "Answer.\n\n**Sources:**\n\n- `#{context_note.path}`", answer
  end

  test "chat leaves out retrieved sections of a note that was picked as context" do
    Note.any_instance.stubs(:fetch_embedding).returns(Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1))

    requested_body = nil
    fake_response = stub("response")
    fake_response.stubs(:read_body).yields({ message: { content: "Answer." }, done: true }.to_json + "\n")
    expectation = Net::HTTP.any_instance.stubs(:request)
    expectation.with { |request| requested_body = JSON.parse(request.body) }
    expectation.yields(fake_response)

    sse = Object.new
    sse.define_singleton_method(:write) { |payload, event: nil| nil }

    Note.chat("What is the architecture?", sse, context_notes: [ notes(:embedded) ])

    user_message = requested_body["messages"].last["content"]
    assert_equal 1, user_message.scan("Source: #{notes(:embedded).path}").size
  end

  test "chat sends the sections of notes with a picked tag as primary context" do
    Note.any_instance.stubs(:fetch_embedding).returns(Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1))

    requested_body = nil
    fake_response = stub("response")
    fake_response.stubs(:read_body).yields({ message: { content: "Answer.\nSOURCES: 1" }, done: true }.to_json + "\n")
    expectation = Net::HTTP.any_instance.stubs(:request)
    expectation.with { |request| requested_body = JSON.parse(request.body) }
    expectation.yields(fake_response)

    sse = Object.new
    sse.define_singleton_method(:write) { |payload, event: nil| nil }

    answer = Note.chat("What is the architecture?", sse, context_tags: [ tags(:ruby) ])

    user_message = requested_body["messages"].last["content"]
    primary, retrieved = user_message.split("Note sections:")
    assert_includes primary, note_sections(:first).content
    assert_includes primary, note_sections(:second).content
    assert_not_includes retrieved, "Source: #{notes(:embedded).path}"
    assert_equal "Answer.\n\n**Sources:**\n\n- `#{notes(:embedded).path}`", answer
  end

  test "chat ignores a picked tag with no notes" do
    Note.any_instance.stubs(:fetch_embedding).returns(Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1))
    fake_response = stub("response")
    fake_response.stubs(:read_body).yields({ message: { content: "Answer." }, done: true }.to_json + "\n")
    Net::HTTP.any_instance.stubs(:request).yields(fake_response)
    sse = Object.new
    sse.define_singleton_method(:write) { |payload, event: nil| nil }

    answer = Note.chat("Anything?", sse, context_tags: [ Tag.create!(name: "unused") ])

    assert_equal "Answer.\n\n**Sources:**\n\n- `#{notes(:embedded).path}`", answer
  end
end
