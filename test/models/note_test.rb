require "test_helper"

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

  test "generate_embedding replaces any previously generated sections" do
    note = notes(:pending_embedding)
    note.define_singleton_method(:fetch_embedding) { |_text| Array.new(NoteSectionEmbedding::DIMENSIONS, 0.1) }

    note.update!(content: "# Only heading\n\nBody.")
    note.generate_embedding
    assert_equal 1, note.note_sections.count

    note.update!(content: "# Only heading\n\nBody.\n\n## Another\n\nMore.")
    note.generate_embedding
    assert_equal 2, note.note_sections.count
  end
end
