class Replication::PushToPeerJob < ApplicationJob
  queue_as :replication

  discard_on ActiveJob::DeserializationError
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(peer)
    return unless peer.active?

    peer.push_changes_now
  end
end
