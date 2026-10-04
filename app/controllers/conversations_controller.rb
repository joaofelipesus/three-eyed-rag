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

  def destroy
    @conversation = Conversation.find(params[:id])

    # the dialog only enables its submit once the confirmation matches; this guards direct requests too
    if params[:confirmation] == @conversation.deletion_confirmation
      @conversation.destroy!
      redirect_to root_path, status: :see_other
    else
      redirect_to conversation_path(@conversation), status: :see_other
    end
  end

  private

  def conversation_params
    params.require(:conversation).permit(:title)
  end
end
