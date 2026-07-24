class CreateConversationMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_messages do |t|
      t.belongs_to :conversation, null: false, foreign_key: true
      t.string :created_by, null: false, comment: "Who sent the message: user or system"
      t.text :content, null: false

      t.timestamps
    end
  end
end
