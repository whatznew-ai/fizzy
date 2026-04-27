module Replication::Trackable
  extend ActiveSupport::Concern

  included do
    after_commit :trigger_replication, if: -> { Replication.enabled }
  end

  private
    def trigger_replication
      Replication::PushToAllPeersJob.perform_later
    end
end
