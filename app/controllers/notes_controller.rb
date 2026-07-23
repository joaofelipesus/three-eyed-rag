class NotesController < ApplicationController
  include ActionController::Live

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

  def chat
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    sse = ActionController::Live::SSE.new(response.stream)

    answer = Note.chat(params[:query], sse)
    sse.write({ html: view_context.markdown(answer) }, event: "done")
  rescue IOError
    # client disconnected before the stream finished
  ensure
    sse.close
  end
end
