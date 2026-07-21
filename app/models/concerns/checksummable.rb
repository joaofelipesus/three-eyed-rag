module Checksummable
  extend ActiveSupport::Concern

  included do
    before_save :generate_checksum, if: :content_changed?
  end

  private

  def generate_checksum
    self.checksum = Digest::SHA256.hexdigest(content.to_s)
  end
end
