module Notes
  module VaultProcessable
    extend ActiveSupport::Concern

    # "Tags: #a #b", or a heading as most vault notes write it: "### Tags: #a #b", or "### Tags:"
    # with the tags on the lines below it
    TAGS_MARKER = /^(?:\#{1,6}[ \t]*Tags:?|Tags:)[ \t]*(.*)$/i
    # "#name" at the start of the text or after whitespace, so heading markers ("### ") and "C#" don't count
    TAG = /(?:^|\s)#([^\s#,;]+)/

    class_methods do
      def process_vault
        update_all(processing_status: :pending)

        files = vault_files
        total = files.size

        files.each_with_index do |file, index|
          content = File.read(file)

          title = File.basename(file, ".md")

          note = find_or_initialize_by(path: file)
          content_unchanged = note.persisted? && note.checksum == Digest::SHA256.hexdigest(content)

          note.update!(
            title: title,
            content: content,
            last_updated_at: File.mtime(file)
          )

          # cheap, so done for unchanged notes too: keeps tags in sync with what the note lists
          note.sync_tags!

          if content_unchanged
            note.processed!
          else
            begin
              # TODO: link related notes once a Note-to-Note relation model exists
              note.generate_embedding

              note.processed!
            rescue StandardError
              note.failed!
            end
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

    # replaces the note's tags with the ones its Tags marker lists
    def sync_tags!
      self.tags = tag_names.map { |name| Tag.find_or_create_by!(name: name) }
    end

    def tag_names
      marker = content.to_s.match(TAGS_MARKER)
      return [] unless marker

      listed = marker[1].presence || content[marker.end(0)..].sub(/\A\s*\n/, "")[/\A.*?(?=\n[ \t]*\n|\n#+\s|\z)/m].to_s
      listed.scan(TAG).flatten.uniq
    end
  end
end
