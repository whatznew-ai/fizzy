require "test_helper"

class Replication::PushToPeerJobTest < ActiveSupport::TestCase
  setup do
    @peer = Replication::Peer.create!(name: "test", base_url: "https://peer.example.com")
  end

  test "skips non-active peers" do
    @peer.update!(state: :paused)
    @peer.expects(:push_changes_now).never

    Replication::PushToPeerJob.perform_now(@peer)
  end

  test "calls push_changes_now on active peer" do
    @peer.expects(:push_changes_now).once

    Replication::PushToPeerJob.perform_now(@peer)
  end

  test "push_to_all_peers_job enqueues per-peer jobs" do
    relation = Replication::Peer.where(id: @peer.id)
    Replication::Peer.stubs(:pushable).returns(relation)

    assert_enqueued_with(job: Replication::PushToPeerJob, args: [ @peer ]) do
      Replication::PushToAllPeersJob.perform_now
    end
  end
end
