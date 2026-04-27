module Replication::Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_peer
    before_action :ensure_replication_enabled
  end

  private
    def authenticate_peer
      peer_id = request.headers["X-Replication-Peer-Id"]
      signature = request.headers["X-Replication-Signature"]

      if peer_id.blank? || signature.blank?
        head :unauthorized and return
      end

      @replication_peer = Replication::Peer.find_by(id: peer_id)

      if @replication_peer.nil?
        head :unauthorized and return
      end

      expected = OpenSSL::HMAC.hexdigest("SHA256", @replication_peer.auth_token, request.raw_post)

      unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)
        head :unauthorized
      end
    end

    def ensure_replication_enabled
      head :service_unavailable unless Replication.enabled
    end
end
