class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  include Replication::Trackable

  configure_replica_connections
end
