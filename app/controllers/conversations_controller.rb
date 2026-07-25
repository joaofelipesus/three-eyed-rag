class ConversationsController < ApplicationController
  def index
    @conversations = Conversation.ordered
  end

  def show
    @conversation = Conversation.find(params[:id])
    @conversation_messages = @conversation.conversation_messages.order(:created_at)
  end

  def update
    @conversation = Conversation.find(params[:id])

    if @conversation.update(conversation_params)
      render turbo_stream: [
        turbo_stream.replace("conversation_title", partial: "conversations/title", locals: { conversation: @conversation }),
        turbo_stream.replace(@conversation, partial: "conversations/sidebar_conversation", locals: { conversation: @conversation })
      ]
    else
      render turbo_stream: turbo_stream.replace("conversation_title", partial: "conversations/title", locals: { conversation: @conversation }),
             status: :unprocessable_entity
    end
  end

  private

  def conversation_params
    params.require(:conversation).permit(:title)
  end
end
