if Fizzy.db_adapter.sqlite?
  ActiveSupport.on_load(:active_record) do
    ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(Module.new do
      def configure_connection
        super

        if Replication.enabled
          raw_connection.enable_load_extension(true)
          raw_connection.load_extension(Replication.crsqlite_extension_path)
          raw_connection.enable_load_extension(false)

          if Replication.site_id.present?
            raw_connection.execute("SELECT crsql_site_id('#{Replication.site_id}')")
          end
        end
      end
    end)
  end
end
