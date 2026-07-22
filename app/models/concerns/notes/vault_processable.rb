module Notes
  module VaultProcessable
    extend ActiveSupport::Concern

    TAGS_LINE_PATTERN = /^Tags:\s*(.+)$/i

    class_methods do
      def process_vault
        update_all(processing_status: :pending)

        files = vault_files

        files.each_with_index do |file, index|
          content = File.read(file)

          title = File.basename(file, ".md")

          note = create!(
            title: title,
            content: content,
            path: file,
            last_updated_at: File.mtime(file)
          )

          begin
            tags_line = content[TAGS_LINE_PATTERN, 1]
            tags_line&.scan(/#(\S+)/)&.flatten&.each do |tag_name|
              tag = Tag.find_or_create_by!(name: tag_name)
              note.note_tags.create!(tag: tag)
            end

            # TODO: link related notes once a Note-to-Note relation model exists
            note.generate_embedding

            note.processed!
          rescue StandardError
            note.failed!
          end

          ActionCable.server.broadcast("vault_processing", {
            note_id: note.id,
            title: note.title,
            status: note.processing_status,
            processed: index + 1,
            total: files.size
          })

          puts "\r#{index + 1} of #{files.size} processed"
        end
      end

      def vault_documents_count
        vault_files.size
      end

      private

      def vault_files
        Dir.glob(Rails.root.join("obsidian_vault", "**", "*.md"))
          .reject { |file| file.include?(".excalidraw") }
      end
    end
  end
end
