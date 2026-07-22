require "net/http"

module Notes
  module Chatable
    extend ActiveSupport::Concern

    NOTE_SECTIONS_LIMIT = 10
    CHAT_MODEL = "qwen3:8b"
    REQUEST_TIMEOUT = 300 # seconds; chat models can take a while to cold-load

    SYSTEM_PROMPT = <<~PROMPT
      You are a helpful assistant answering questions using the user's personal notes.
      You will receive the user's message and a list of note sections retrieved for it.
      Evaluate which of the note sections are actually related to the message and base your
      answer only on those, ignoring any that aren't relevant.

      You must always format the answer as Markdown:
      - Use headings or bold text to highlight key terms, not wall-of-text paragraphs.
      - Use bullet or numbered lists whenever you present multiple items or steps.
      - Use fenced code blocks for code, commands, or file paths quoted verbatim.
      - Keep paragraphs short and scannable.

      End the answer with a "**Sources:**" section listing, as a bullet list, the path of every
      note used to build the answer. There can be more than one source. If none of the note
      sections are relevant, say so instead of making up an answer, and omit the sources section.
    PROMPT

    class_methods do
      def chat(question)
        embedding = new.send(:fetch_embedding, question)
        note_sections = matching_note_sections(embedding)

        request_chat_completion(question, note_sections)
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

      def request_chat_completion(question, note_sections)
        uri = URI("#{Notes::Embeddable::OLLAMA_HOST}/api/chat")

        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = REQUEST_TIMEOUT
        http.read_timeout = REQUEST_TIMEOUT

        response = http.post(
          uri,
          {
            model: CHAT_MODEL,
            messages: [
              { role: "system", content: SYSTEM_PROMPT },
              { role: "user", content: chat_prompt(question, note_sections) }
            ],
            stream: false
          }.to_json,
          "Content-Type" => "application/json"
        )

        JSON.parse(response.body).dig("message", "content")
      end

      def chat_prompt(question, note_sections)
        sections = note_sections.map do |section|
          "Source: #{section.note.path}\n#{section.content}"
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
