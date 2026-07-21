module Notes
  module VaultProcessable
    extend ActiveSupport::Concern

    TAGS_LINE_PATTERN = /^Tags:\s*(.+)$/i

    class_methods do
      def process_vault
        files = Dir.glob(Rails.root.join("obsidian_vault", "**", "*.md"))
          .reject { |file| file.include?(".excalidraw") }

        files.each_with_index do |file, index|
          content = File.read(file)

          title = File.basename(file, ".md")

          note = create!(
            title: title,
            content: content,
            path: file,
            last_updated_at: File.mtime(file)
          )

          tags_line = content[TAGS_LINE_PATTERN, 1]
          tags_line&.scan(/#(\S+)/)&.flatten&.each do |tag_name|
            tag = Tag.find_or_create_by!(name: tag_name)
            note.note_tags.create!(tag: tag)
          end

          # TODO: link related notes once a Note-to-Note relation model exists

          # TODO fix embedding and continue
          # begin
            note.generate_embedding
          # rescue StandardError => e

          # end

          puts "\r#{index + 1} of #{files.size} processed"
        end
      end
    end
  end
end
