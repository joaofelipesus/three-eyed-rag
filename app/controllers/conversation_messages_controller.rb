class ConversationMessagesController < ApplicationController
  include ActionController::Live

  # create or use current conversation
  # create received message from the user
  # use SSE to return the response
  # create a message with the response with the complete payload
  def create
    # if there is no conversation_id the user is in the home starting a new conversation
    starting_new_conversation = params[:conversation_id].blank?
    @conversation = starting_new_conversation ? Conversation.start! : Conversation.find(params[:conversation_id])
    @conversation.conversation_messages.create!(created_by: :user, content: params[:content])

    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    sse = ActionController::Live::SSE.new(response.stream)

    answer = Note.chat(params[:content], sse)
    @conversation.conversation_messages.create!(created_by: :system, content: answer)

    sse.write(done_payload(answer, starting_new_conversation), event: "done")
  rescue IOError
    # client disconnected before the stream finished
  ensure
    sse.close
  end

  private

  def done_payload(answer, starting_new_conversation)
    payload = { html: view_context.markdown(answer) }
    payload[:conversation] = {
      id: @conversation.id,
      title: @conversation.title,
      url: conversation_path(@conversation)
    } if starting_new_conversation

    payload
  end
end
