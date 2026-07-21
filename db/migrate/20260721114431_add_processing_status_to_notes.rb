class AddProcessingStatusToNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :notes, :processing_status, :string, default: "pending", null: false,
      comment: "Vault processing status of the note: pending, processed or failed"
  end
end
