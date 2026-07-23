require "net/http"

module Notes
  module Chatable
    extend ActiveSupport::Concern

    NOTE_SECTIONS_LIMIT = 10
    CHAT_MODEL = "qwen3:8b"
    REQUEST_TIMEOUT = 300 # seconds; chat models can take a while to cold-load

    SYSTEM_PROMPT = <<~PROMPT
      You are a helpful assistant answering questions using the user's personal notes.
      You will receive the user's message and a list of note sections retrieved for it, each
      labeled with a number like [1], [2]. Evaluate which of the note sections are actually
      related to the message and base your answer only on those, ignoring any that aren't
      relevant.

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

    class_methods do
      def chat(question, sse)
        embedding = new.send(:fetch_embedding, question)
        note_sections = matching_note_sections(embedding).to_a

        raw_answer = request_chat_completion(question, note_sections, sse)
        append_sources(raw_answer, note_sections)
      end

      private

      def matching_note_sections(embedding)
        packed_embedding = ActiveModel::Type::Binary::Data.new(embedding.pack("f*"))

        note_section_ids = NoteSectionEmbedding
          .where("embedding MATCH ? AND k = ?", packed_embedding, NOTE_SECTIONS_LIMIT)
          .order(:distance)
          .pluck(:note_section_id)

        NoteSection.where(id: note_section_ids).includes(:note)
      end

      # The model reliably mangles a hand-written Markdown list of file paths (missing
      # separators, broken code fences), so instead of trusting it to format the Sources
      # section itself, it only reports back which numbered sections it used and this builds
      # that section deterministically from the actual note_sections used to construct the
      # prompt.
      def append_sources(raw_answer, note_sections)
        match = raw_answer.match(SOURCES_DIRECTIVE)
        body = match ? raw_answer[0...match.begin(0)].strip : raw_answer.strip
        directive = match && match[1].strip

        used_sections = resolve_sources(directive, note_sections)
        return body if used_sections.empty?

        paths = used_sections.map { |section| section.note.path }.uniq
        sources_list = paths.map { |path| "- `#{path}`" }.join("\n")

        "#{body}\n\n**Sources:**\n\n#{sources_list}"
      end

      def resolve_sources(directive, note_sections)
        return note_sections if directive.blank?
        return [] if directive.casecmp("none").zero?

        indexes = directive.scan(/\d+/).map(&:to_i)
        indexes.filter_map { |index| note_sections[index - 1] }
      end

      # streams the model's response token by token, writing each chunk to the given SSE
      # object as it arrives instead of waiting for the full answer; returns the full answer
      # once the model reports it's done, so the caller can still do something with it (e.g.
      # render it as Markdown for a final, formatted event).
      def request_chat_completion(question, note_sections, sse)
        uri = URI("#{Notes::Embeddable::OLLAMA_HOST}/api/chat")

        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = REQUEST_TIMEOUT
        http.read_timeout = REQUEST_TIMEOUT

        request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        request.body = {
          model: CHAT_MODEL,
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: chat_prompt(question, note_sections) }
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

      def chat_prompt(question, note_sections)
        sections = note_sections.each_with_index.map do |section, index|
          "[#{index + 1}] Source: #{section.note.path}\n#{section.content}"
        end.join("\n\n---\n\n")

        <<~PROMPT
          Message: #{question}

          Note sections:
          #{sections}
        PROMPT
      end
    end
  end
end
