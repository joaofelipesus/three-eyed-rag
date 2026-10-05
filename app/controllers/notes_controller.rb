class NotesController < ApplicationController
  # suggestions for the chat input's "#" autocomplete, matched by note file name
  def search
    @query = params[:q].to_s.strip
    @notes = Note.search_by_title(@query, exclude: params[:exclude])

    render partial: "notes/search_results", locals: { notes: @notes, query: @query }
  end

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
