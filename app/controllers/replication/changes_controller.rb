class Replication::ChangesController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :require_account

  include Replication::Authentication

  def index
    since = params.fetch(:since_db_version, 0).to_i
    limit = [ params.fetch(:limit, 1000).to_i, 5000 ].min

    changes = Replication::Change.since(since, limit: limit)

    render json: {
      changes: changes,
      current_db_version: Replication::Change.current_db_version
    }
  end

  def create
    body = decompress_if_needed(request.raw_post)
    changes = Replication::Change.deserialize(body)
    Replication::Change.apply(changes)

    render json: { applied: changes.size, current_db_version: Replication::Change.current_db_version }
  end

  private
    def decompress_if_needed(raw)
      if request.headers["Content-Encoding"] == "gzip"
        Zlib::GzipReader.new(StringIO.new(raw)).read
      else
        raw
      end
    end
end
