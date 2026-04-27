require "test_helper"

class Replication::PeerTest < ActiveSupport::TestCase
  setup do
    @peer = Replication::Peer.create!(
      name: "staging",
      base_url: "https://staging.example.com"
    )
  end

  test "generates auth_token on create" do
    assert @peer.auth_token.present?
  end

  test "defaults to active state" do
    assert @peer.active?
  end

  test "record_push_success advances watermark and resets failures" do
    @peer.update!(consecutive_failures: 3)
    @peer.record_push_success(42)

    assert_equal 42, @peer.last_sent_db_version
    assert_equal 0, @peer.consecutive_failures
    assert @peer.last_pushed_at.present?
    assert @peer.active?
  end

  test "record_push_failure increments consecutive failures" do
    assert_difference -> { @peer.reload.consecutive_failures }, +1 do
      @peer.record_push_failure
    end
  end

  test "circuit breaker triggers error state after max failures" do
    @peer.update!(consecutive_failures: Replication::Peer::MAX_CONSECUTIVE_FAILURES - 1)
    @peer.record_push_failure

    assert @peer.reload.error?
  end

  test "pushable scope excludes paused and error peers" do
    active_peer = @peer
    paused_peer = Replication::Peer.create!(name: "paused", base_url: "https://paused.example.com", state: :paused)
    error_peer = Replication::Peer.create!(name: "error", base_url: "https://error.example.com", state: :error)

    pushable = Replication::Peer.active
    assert_includes pushable, active_peer
    assert_not_includes pushable, paused_peer
    assert_not_includes pushable, error_peer
  end

  test "validates presence of name and base_url" do
    peer = Replication::Peer.new
    assert_not peer.valid?
    assert peer.errors[:name].any?
    assert peer.errors[:base_url].any?
  end
end
