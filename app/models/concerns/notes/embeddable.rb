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

    # matches Obsidian's embed syntax for images, e.g. "![[Screenshot 2026-07-08 at 11.06.19.png]]"
    IMAGE_EMBED_PATTERN = /!\[\[([^\[\]]+\.(?:jpe?g|png|tif))\]\]/i

    def generate_embedding
      retained_section_ids = split_into_sections(content).map do |section_content|
        existing_section = note_sections.find_by(checksum: Digest::SHA256.hexdigest(section_content))
        next existing_section.id if existing_section

        section = note_sections.create!(content: section_content)
        attach_images(section, section_content)

        embedding_vector = fetch_embedding(section_content)

        (section.note_section_embedding || section.build_note_section_embedding).update!(embedding: embedding_vector)

        section.id
      end

      note_sections.where.not(id: retained_section_ids).destroy_all

      update!(last_embeded_at: Time.current)
    end

    private

    def attach_images(section, section_content)
      section_content.scan(IMAGE_EMBED_PATTERN).flatten.each do |filename|
        path = vault_asset_path(filename)
        next unless path

        section.images.attach(io: File.open(path), filename: File.basename(path))
      end
    end

    def vault_asset_path(filename)
      Dir.glob(Rails.root.join("obsidian_vault", "**", filename)).first
    end

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
