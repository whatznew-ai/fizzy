class Replication::Change
  class << self
    def since(db_version, limit: 1000)
      rows = connection.select_all(
        "SELECT \"table\", pk, cid, val, col_version, db_version, site_id, cl, seq " \
        "FROM crsql_changes WHERE db_version > ? ORDER BY db_version, seq LIMIT ?",
        "Replication::Change Load",
        [ db_version, limit ]
      )

      rows.map { |row| normalize(row) }
    end

    def apply(changes)
      connection.transaction do
        changes.each do |change|
          connection.execute(
            "INSERT INTO crsql_changes (\"table\", pk, cid, val, col_version, db_version, site_id, cl, seq) " \
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [ change["table"], change["pk"], change["cid"], change["val"],
              change["col_version"], change["db_version"], decode_site_id(change["site_id"]),
              change["cl"], change["seq"] ]
          )
        end
      end
    end

    def current_db_version
      connection.select_value("SELECT crsql_db_version()")
    end

    def site_id
      raw = connection.select_value("SELECT crsql_site_id()")
      Base64.strict_encode64(raw.dup.force_encoding("BINARY"))
    end

    def serialize(changes)
      JSON.generate(changes)
    end

    def deserialize(json)
      JSON.parse(json)
    end

    private
      def connection
        ActiveRecord::Base.connection
      end

      def normalize(row)
        result = row.to_h
        if result["site_id"]
          result["site_id"] = Base64.strict_encode64(result["site_id"].dup.force_encoding("BINARY"))
        end
        result
      end

      def decode_site_id(encoded)
        if encoded
          Base64.strict_decode64(encoded)
        end
      end
  end
end
