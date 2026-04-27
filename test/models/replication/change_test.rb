require "test_helper"

class Replication::ChangeTest < ActiveSupport::TestCase
  test "current_db_version returns an integer" do
    skip "cr-sqlite extension not loaded" unless Replication.enabled
    assert_kind_of Integer, Replication::Change.current_db_version
  end

  test "site_id returns base64-encoded string" do
    skip "cr-sqlite extension not loaded" unless Replication.enabled
    site_id = Replication::Change.site_id
    assert_kind_of String, site_id
    assert_nothing_raised { Base64.strict_decode64(site_id) }
  end

  test "since returns changes after given version" do
    skip "cr-sqlite extension not loaded" unless Replication.enabled
    changes = Replication::Change.since(0, limit: 10)
    assert_kind_of Array, changes
  end

  test "serialize and deserialize round-trip" do
    changes = [
      { "table" => "cards", "pk" => "abc123", "cid" => "title", "val" => "Hello",
        "col_version" => 1, "db_version" => 1, "site_id" => Base64.strict_encode64("site1"),
        "cl" => 1, "seq" => 0 }
    ]

    json = Replication::Change.serialize(changes)
    result = Replication::Change.deserialize(json)

    assert_equal changes, result
  end
end
