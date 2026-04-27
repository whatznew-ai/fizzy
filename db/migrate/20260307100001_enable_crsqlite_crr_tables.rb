class EnableCrsqliteCrrTables < ActiveRecord::Migration[8.2]
  SYNCED_TABLES = %w[
    accesses
    accounts
    account_cancellations
    account_join_codes
    action_text_rich_texts
    active_storage_attachments
    active_storage_blobs
    assignments
    board_publications
    boards
    card_goldnesses
    card_not_nows
    cards
    closures
    columns
    comments
    entropies
    events
    identities
    mentions
    notifications
    notification_bundles
    pins
    reactions
    steps
    taggings
    tags
    users
    watches
    webhooks
    webhook_delinquency_trackers
  ].freeze

  def up
    return unless Fizzy.db_adapter.sqlite? && Replication.enabled

    SYNCED_TABLES.each do |table|
      execute "SELECT crsql_as_crr('#{table}')"
    end
  end

  def down
    return unless Fizzy.db_adapter.sqlite? && Replication.enabled

    SYNCED_TABLES.each do |table|
      execute "SELECT crsql_begin_alter('#{table}')"
      execute "SELECT crsql_commit_alter('#{table}')"
    end
  end
end
