require "test_helper"

class Replication::ChangesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @peer = Replication::Peer.create!(name: "test-peer", base_url: "https://peer.example.com")
    integration_session.default_url_options[:script_name] = ""
  end

  test "index requires authentication" do
    get replication_changes_path
    assert_response :unauthorized
  end

  test "index with valid HMAC returns changes" do
    skip "cr-sqlite extension not loaded" unless Replication.enabled

    get replication_changes_path(since_db_version: 0),
      headers: signed_headers("")

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("changes")
    assert json.key?("current_db_version")
  end

  test "create requires authentication" do
    post replication_changes_path, params: "[]", as: :json
    assert_response :unauthorized
  end

  test "create with invalid HMAC returns unauthorized" do
    post replication_changes_path,
      params: "[]",
      headers: {
        "Content-Type" => "application/json",
        "X-Replication-Peer-Id" => @peer.id,
        "X-Replication-Signature" => "invalid"
      }

    assert_response :unauthorized
  end

  test "create with valid HMAC applies changes" do
    skip "cr-sqlite extension not loaded" unless Replication.enabled

    payload = "[]"
    post replication_changes_path,
      params: payload,
      headers: signed_headers(payload).merge("Content-Type" => "application/json")

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 0, json["applied"]
  end

  private
    def signed_headers(body)
      signature = OpenSSL::HMAC.hexdigest("SHA256", @peer.auth_token, body)
      {
        "X-Replication-Peer-Id" => @peer.id,
        "X-Replication-Signature" => signature
      }
    end
end
