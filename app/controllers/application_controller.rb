class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  SIDEBAR_CONVERSATIONS_LIMIT = 5

  helper_method :sidebar_conversations

  private

  # define the method sidebar_conversations on ApplicationController because it's used on a shared context,
  # since it's called in the sidebar.
  def sidebar_conversations
    Conversation.ordered.limit(SIDEBAR_CONVERSATIONS_LIMIT)
  end
end
