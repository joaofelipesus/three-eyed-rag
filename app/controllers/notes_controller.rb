class NotesController < ApplicationController
  def reload_valut
    Note.process_vault

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { head :ok }
    end
  end
end
