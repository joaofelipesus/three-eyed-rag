class ProcessVaultJob < ApplicationJob
  queue_as :default

  def perform
    Note.process_vault
  end
end
