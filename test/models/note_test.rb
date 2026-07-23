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
    assert_equal ["can't be blank"], note.errors[:title]
    assert_equal ["can't be blank"], note.errors[:path]
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

  test "process_vault skips retagging and re-embedding a note whose checksum is unchanged" do
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
end
