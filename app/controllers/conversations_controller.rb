class ConversationsController < ApplicationController
  def index
    @conversations = Conversation.ordered
  end

  def show
    @conversation = Conversation.find(params[:id])
    @conversation_messages = @conversation.conversation_messages.order(:created_at)
  end
end
