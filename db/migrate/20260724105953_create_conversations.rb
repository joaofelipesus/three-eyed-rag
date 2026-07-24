class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.string :title, null: false, comment: 'Conversation title'

      t.timestamps
    end
    add_index :conversations, :title, unique: true
  end
end
