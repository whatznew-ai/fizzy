class Replication::PushToAllPeersJob < ApplicationJob
  queue_as :replication

  def perform
    Replication::Peer.pushable.find_each do |peer|
      Replication::PushToPeerJob.perform_later(peer)
    end
  end
end
