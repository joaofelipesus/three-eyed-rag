require "net/http"

module Notes
  module Embeddable
    extend ActiveSupport::Concern

    OLLAMA_HOST = ENV.fetch("OLLAMA_HOST", "http://host.docker.internal:11434")
    EMBEDDING_MODEL = "qwen3-embedding:4b" # embedding size 2560, and 8b 4096
    REQUEST_TIMEOUT = 300 # seconds; embedding models can take a while to cold-load

    # delay before each retry when a request comes back without an embedding (e.g. the
    # model is still cold-loading); escalates one second at a time
    EMBEDDING_RETRY_DELAYS = [1, 2, 3, 4, 5].freeze

    # matches lines starting with a level 1-3 heading ("#", "##" or "###"); a run of 4+ "#"
    # fails to match since the heading char run must be followed directly by whitespace, so
    # "####" sections stay part of whichever section is currently being built
    SECTION_HEADING_PATTERN = /^(?:###|##|#)[ \t]+\S.*$/

    # metadata sections (e.g. "### Related notes:" or "### Tags: #foo") aren't real content,
    # so they're dropped instead of becoming their own note section
    IGNORED_SECTION_TITLES_PATTERN = /\A(?:related notes|tags)\b/i

    def generate_embedding
      note_sections.destroy_all

      split_into_sections(content).each do |section_content|
        section = note_sections.create!(content: section_content)
        embedding_vector = fetch_embedding(section_content)

        debugger if embedding_vector.nil?

        (section.note_section_embedding || section.build_note_section_embedding).update!(embedding: embedding_vector)
      end

      update!(last_embeded_at: Time.current)
    end

    private

    def split_into_sections(text)
      sections = []
      current_section = nil

      text.to_s.each_line do |line|
        if line.match?(SECTION_HEADING_PATTERN)
          sections << current_section if current_section
          current_section = +line
        elsif current_section
          current_section << line
        else
          current_section = +line
        end
      end
      sections << current_section if current_section

      sections.map(&:strip).reject(&:empty?).reject { |section| ignored_section?(section) }
    end

    def ignored_section?(section)
      heading_text = section.lines.first.to_s.sub(/\A#+[ \t]*/, "").strip

      heading_text.match?(IGNORED_SECTION_TITLES_PATTERN)
    end

    def fetch_embedding(text)
      embedding_vector = request_embedding(text)
      return embedding_vector if embedding_vector.present?

      EMBEDDING_RETRY_DELAYS.each do |delay|
        sleep(delay)

        embedding_vector = request_embedding(text)
        return embedding_vector if embedding_vector.present?
      end

      embedding_vector
    end

    def request_embedding(text)
      uri = URI("#{OLLAMA_HOST}/api/embeddings")

      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = REQUEST_TIMEOUT
      http.read_timeout = REQUEST_TIMEOUT

      response = http.post(
        uri,
        { model: EMBEDDING_MODEL, prompt: text }.to_json,
        "Content-Type" => "application/json"
      )

      JSON.parse(response.body)["embedding"]
    end
  end
end
