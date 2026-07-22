class VaultProcessingChannel < ApplicationCable::Channel
  def subscribed
    stream_from "vault_processing"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
