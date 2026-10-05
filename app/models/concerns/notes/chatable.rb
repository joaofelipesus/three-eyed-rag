require "net/http"
require "base64"

module Notes
  module Chatable
    extend ActiveSupport::Concern

    NOTE_SECTIONS_LIMIT = 10
    CONTEXT_NOTES_LIMIT = 5
    CONTEXT_TAGS_LIMIT = 5
    # a tag can cover many notes, so a picked tag adds only its notes' sections nearest the question
    TAGGED_SECTIONS_LIMIT = 6
    # whole notes picked as context can be long; cap each so the prompt stays within the model's context window
    CONTEXT_NOTE_CHARACTER_LIMIT = 8_000
    CHAT_MODEL = "qwen3:8b"
    IMAGE_MODEL = "qwen2.5vl:7b"
    REQUEST_TIMEOUT = 300 # seconds; chat models can take a while to cold-load

    IMAGE_RELEVANCE_PROMPT = <<~PROMPT
      The user asked: "%{question}"

      This image was found attached to a note section used to answer that question. Decide
      whether it visually shows something relevant and worth including alongside the answer
      (e.g. a diagram, screenshot, or illustration directly related to the topic), as opposed
      to being incidental or unrelated to what was asked. Respond with exactly one word: YES
      or NO.
    PROMPT

    SYSTEM_PROMPT = <<~PROMPT
      You are a helpful assistant answering questions using the user's personal notes.
      You will receive the user's message and a list of note sections retrieved for it, each
      labeled with a number like [1], [2]. Evaluate which of the note sections are actually related
      to the message and base your answer only on those, ignoring any that aren't relevant.

      Some numbered items may be listed under "Primary context": those are whole notes, or
      sections of notes with a tag, that the user explicitly picked for this message. Treat them
      as the most important sources: give them more weight than the other note sections and
      prefer them whenever they're relevant.

      You must always format the answer as Markdown, following these rules exactly so it
      renders correctly:
      - Separate every paragraph, heading, and list from what comes before and after it with
        one blank line. Never let list text run directly into the next sentence or section.
      - A bullet list must ALWAYS have a blank line directly above its first "-" line, even
        when the list follows a heading or a bold label. A label or heading immediately
        followed by a list on the very next line, with no blank line between them, will break
        the rendering — do not do this.
      - Prefer a single flat bullet list over nested lists. Do not indent a bullet inside
        another bullet; if you need sub-points, write them as their own top-level bullets
        instead of nesting.
      - One item per line, each starting with "- " at the start of the line (no leading spaces).
      - Use bold text for key terms rather than walls of prose; use headings only to separate
        clearly distinct topics.
      - Wrap file paths, commands, and any single-line snippet in single backticks, e.g.
        `go mod init module-name`. Never use triple-backtick fences for a one-liner. Only use
        triple-backtick fences for genuinely multi-line code, and when you do, the opening
        fence, each line of code, and the closing fence must each be on their own line —
        never combine them onto the same line.

      Do not write a "Sources" section yourself, and do not repeat the note paths anywhere in
      your answer. Instead, after your answer, on its own final line, write exactly:
      SOURCES: <comma-separated numbers of the sections you actually used, e.g. "1, 3">
      If none of the note sections were relevant, write "SOURCES: none" on that line instead,
      and say so in your answer rather than making up information. Do not add anything else to
      that line.
    PROMPT

    SOURCES_DIRECTIVE = /\n?^SOURCES:[ \t]*(.*)$\z/i
    SOURCES_HEADING = "**Sources:**"
    SOURCE_ITEM = /\A- `(.+)`\z/

    class_methods do
      # Primary context the user picked for this message, sent ahead of the retrieved sections:
      # context_notes are sent whole; context_tags add their notes' sections nearest the question.
      def chat(question, sse, context_notes: [], context_tags: [])
        embedding = new.send(:fetch_embedding, question)
        context_notes = context_notes.first(CONTEXT_NOTES_LIMIT)
        tagged_sections = nearest_tagged_sections(embedding, context_tags.first(CONTEXT_TAGS_LIMIT), except_notes: context_notes)
        primary_context = context_notes + tagged_sections

        # don't repeat what's already in the prompt as primary context
        note_sections = matching_note_sections(embedding).reject do |section|
          context_notes.include?(section.note) || tagged_sections.include?(section)
        end

        raw_answer = request_chat_completion(question, primary_context, note_sections, sse)
        finalize_answer(question, raw_answer, primary_context + note_sections)
      end

      # Splits the Sources list that sources_section appends to an answer back off it, so it
      # can be displayed on its own. Returns [answer body, note paths]; an answer without a
      # well-formed trailing Sources list comes back whole, with no paths.
      def split_sources(answer)
        heading_index = answer.rindex(SOURCES_HEADING)
        return [ answer, [] ] unless heading_index

        lines = answer[(heading_index + SOURCES_HEADING.length)..].split("\n").map(&:strip).compact_blank
        return [ answer, [] ] unless lines.any? && lines.all? { |line| line.match?(SOURCE_ITEM) }

        [ answer[0...heading_index].rstrip, lines.map { |line| line[SOURCE_ITEM, 1] } ]
      end

      private

      # sections of the notes with any of the tags, nearest the question first; a brute-force
      # distance over just those sections, since the KNN MATCH can't be limited to a set of notes
      def nearest_tagged_sections(embedding, tags, except_notes: [])
        return [] if tags.empty?

        section_ids = NoteSection.joins(note: :note_tags).where(note_tags: { tag_id: tags })
          .where.not(note_id: except_notes).distinct.pluck(:id)
        return [] if section_ids.empty?

        distance = sanitize_sql_array([ "vec_distance_l2(embedding, ?)", packed(embedding) ])
        nearest_ids = NoteSectionEmbedding.where(note_section_id: section_ids)
          .order(Arel.sql(distance)).limit(TAGGED_SECTIONS_LIMIT).pluck(:note_section_id)

        NoteSection.where(id: nearest_ids).includes(:note, images_attachments: :blob)
          .sort_by { |section| nearest_ids.index(section.id) }
      end

      def packed(embedding)
        ActiveModel::Type::Binary::Data.new(embedding.pack("f*"))
      end

      def matching_note_sections(embedding)
        packed_embedding = packed(embedding)

        note_section_ids = NoteSectionEmbedding
          .where("embedding MATCH ? AND k = ?", packed_embedding, NOTE_SECTIONS_LIMIT)
          .order(:distance)
          .pluck(:note_section_id)

        NoteSection.where(id: note_section_ids).includes(:note, images_attachments: :blob)
      end

      # The model reliably mangles a hand-written Markdown list of file paths (missing
      # separators, broken code fences), so instead of trusting it to format the Sources and
      # images itself, it only reports back which numbered items it used and this builds
      # both sections deterministically from the actual sources used to construct the
      # prompt: the primary context (picked notes, then tagged sections) followed by the
      # retrieved sections.
      def finalize_answer(question, raw_answer, sources)
        match = raw_answer.match(SOURCES_DIRECTIVE)
        body = match ? raw_answer[0...match.begin(0)].strip : raw_answer.strip
        directive = match && match[1].strip

        used_sources = resolve_sources(directive, sources)
        return body if used_sources.empty?

        used_sections = used_sources.grep(NoteSection)
        [ body, images_section(question, used_sections), sources_section(used_sources) ].compact.join("\n\n")
      end

      def resolve_sources(directive, sources)
        return sources if directive.blank?
        return [] if directive.casecmp("none").zero?

        indexes = directive.scan(/\d+/).map(&:to_i)
        indexes.filter_map { |index| sources[index - 1] }
      end

      def images_section(question, sections)
        images = sections.flat_map { |section| section.images.to_a }.uniq(&:blob_id)
        relevant_images = images.select { |image| image_relevant?(question, image) }
        return nil if relevant_images.empty?

        relevant_images.map do |image|
          url = Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
          "![#{image.filename}](#{url})"
        end.join("\n\n")
      end

      def sources_section(sources)
        paths = sources.map { |source| source.is_a?(Note) ? source.path : source.note.path }.uniq
        "#{SOURCES_HEADING}\n\n#{paths.map { |path| "- `#{path}`" }.join("\n")}"
      end

      # qwen3:8b (the main chat model) can't see images, so relevance is judged by a
      # separate vision-capable model instead of trusting the text model to guess from a
      # filename. Each candidate image gets its own quick yes/no classification call.
      def image_relevant?(question, image)
        uri = URI("#{Notes::Embeddable::OLLAMA_HOST}/api/chat")

        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = REQUEST_TIMEOUT
        http.read_timeout = REQUEST_TIMEOUT

        request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        request.body = {
          model: IMAGE_MODEL,
          stream: false,
          messages: [
            {
              role: "user",
              content: format(IMAGE_RELEVANCE_PROMPT, question: question),
              images: [ Base64.strict_encode64(image.download) ]
            }
          ]
        }.to_json

        response = http.request(request)
        JSON.parse(response.body).dig("message", "content").to_s.strip.match?(/\Ayes\b/i)
      end

      # streams the model's response token by token, writing each chunk to the given SSE
      # object as it arrives instead of waiting for the full answer; returns the full answer
      # once the model reports it's done, so the caller can still do something with it (e.g.
      # render it as Markdown for a final, formatted event).
      def request_chat_completion(question, primary_context, note_sections, sse)
        uri = URI("#{Notes::Embeddable::OLLAMA_HOST}/api/chat")

        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = REQUEST_TIMEOUT
        http.read_timeout = REQUEST_TIMEOUT

        request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        request.body = {
          model: CHAT_MODEL,
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: chat_prompt(question, primary_context, note_sections) }
          ],
          stream: true
        }.to_json

        answer = +""
        buffer = +""

        http.request(request) do |response|
          response.read_body do |chunk|
            buffer << chunk

            while (newline_index = buffer.index("\n"))
              line = buffer.slice!(0..newline_index).strip
              next if line.empty?

              payload = JSON.parse(line)
              content = payload.dig("message", "content")

              if content.present?
                answer << content
                sse.write({ content: content }, event: "chunk")
              end

              return answer if payload["done"]
            end
          end
        end

        answer
      end

      # numbers the primary context first, then the retrieved sections, matching the order
      # finalize_answer resolves the model's SOURCES numbers against
      def chat_prompt(question, primary_context, note_sections)
        primary = primary_context.each_with_index.map do |source, index|
          if source.is_a?(Note)
            "[#{index + 1}] Source: #{source.path}\n#{source.content.to_s.truncate(CONTEXT_NOTE_CHARACTER_LIMIT)}"
          else
            "[#{index + 1}] Source: #{source.note.path}\n#{source.content}"
          end
        end
        sections = note_sections.each_with_index.map do |section, index|
          "[#{primary_context.size + index + 1}] Source: #{section.note.path}\n#{section.content}"
        end

        parts = [ "Message: #{question}" ]
        parts << "Primary context (picked by the user for this message):\n\n#{primary.join("\n\n---\n\n")}" if primary.any?
        parts << "Note sections:\n#{sections.join("\n\n---\n\n")}"
        parts.join("\n\n") + "\n"
      end
    end
  end
end
