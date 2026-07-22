module Notes
  module VaultProcessable
    extend ActiveSupport::Concern

    TAGS_LINE_PATTERN = /^Tags:\s*(.+)$/i

    class_methods do
      def process_vault
        update_all(processing_status: :pending)

        files = vault_files
        total = files.size

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

          broadcast_vault_progress(index + 1, total)

          puts "\r#{index + 1} of #{total} processed"
        end

        broadcast_vault_finished
      end

      def vault_documents_count
        vault_files.size
      end

      private

      def vault_files
        Dir.glob(Rails.root.join("obsidian_vault", "**", "*.md"))
          .reject { |file| file.include?(".excalidraw") }
      end

      def broadcast_vault_progress(processed, total)
        Turbo::StreamsChannel.broadcast_replace_to(
          "vault_processing",
          target: "vault_reload_widget",
          partial: "notes/vault_progress",
          locals: { processed: processed, total: total }
        )
      end

      def broadcast_vault_finished
        Turbo::StreamsChannel.broadcast_replace_to(
          "vault_processing",
          target: "vault_reload_widget",
          partial: "notes/vault_reload_widget"
        )
      end
    end
  end
end
