class NotesController < ApplicationController
  def reload_valut
    total = Note.vault_documents_count
    ProcessVaultJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "vault_reload_widget",
          partial: "notes/vault_progress",
          locals: { processed: 0, total: total }
        )
      end
      format.html { head :ok }
    end
  end
end
