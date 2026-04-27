module Replication
  mattr_accessor :enabled, default: ENV["REPLICATION_ENABLED"] == "true" && Fizzy.db_adapter.sqlite?
  mattr_accessor :site_id, default: ENV["REPLICATION_SITE_ID"]

  def self.crsqlite_extension_path
    @crsqlite_extension_path ||= begin
      path = ENV.fetch("CRSQLITE_EXTENSION_PATH") {
        File.expand_path("../../lib/crsqlite/crsqlite", __dir__)
      }
      raise "cr-sqlite extension not found at #{path}" unless File.exist?("#{path}.dylib") || File.exist?("#{path}.so") || File.exist?(path)
      path
    end
  end
end
