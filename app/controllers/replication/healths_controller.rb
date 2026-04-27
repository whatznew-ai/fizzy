class Replication::HealthsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :require_account

  def show
    head :service_unavailable and return unless Replication.enabled

    peers = Replication::Peer.all.map do |peer|
      {
        id: peer.id,
        name: peer.name,
        state: peer.state,
        last_pushed_at: peer.last_pushed_at,
        last_pulled_at: peer.last_pulled_at,
        lag: Replication::Change.current_db_version - peer.last_sent_db_version
      }
    end

    render json: {
      site_id: Replication::Change.site_id,
      db_version: Replication::Change.current_db_version,
      peers: peers
    }
  end
end
