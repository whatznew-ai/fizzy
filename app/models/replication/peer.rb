class Replication::Peer < ApplicationRecord
  self.table_name = "replication_peers"

  MAX_CONSECUTIVE_FAILURES = 10
  PUSH_BATCH_SIZE = 200

  enum :state, { active: "active", paused: "paused", error: "error" }

  has_secure_token :auth_token

  validates :name, :base_url, presence: true

  scope :pushable, -> {
    active.where("last_sent_db_version < ?", Replication::Change.current_db_version)
  }

  def push_changes_now
    changes = Replication::Change.since(last_sent_db_version, limit: PUSH_BATCH_SIZE)
    return if changes.empty?

    response = post_changes(changes)

    if response.is_a?(Net::HTTPSuccess)
      new_version = changes.last[:db_version]
      record_push_success(new_version)
    else
      record_push_failure
    end
  end

  def record_push_success(version)
    update!(
      last_sent_db_version: version,
      last_pushed_at: Time.current,
      consecutive_failures: 0,
      state: :active
    )
  end

  def record_push_failure
    increment!(:consecutive_failures)

    if consecutive_failures >= MAX_CONSECUTIVE_FAILURES
      error!
    end
  end

  private
    def post_changes(changes)
      uri = URI.join(base_url, "/replication/changes")
      payload = Replication::Change.serialize(changes)

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Content-Encoding"] = "gzip"
      request["X-Replication-Peer-Id"] = id
      request["X-Replication-Signature"] = sign(payload)

      compressed = compress(payload)
      request.body = compressed

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
        http.request(request)
      end
    end

    def sign(payload)
      OpenSSL::HMAC.hexdigest("SHA256", auth_token, payload)
    end

    def compress(data)
      io = StringIO.new
      gz = Zlib::GzipWriter.new(io)
      gz.write(data)
      gz.close
      io.string
    end
end
