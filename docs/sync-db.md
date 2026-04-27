# Bidirectional SQLite Sync via cr-sqlite

Fizzy OSS uses SQLite. This system enables bidirectional multi-writer sync between two Fizzy SQLite instances using CRDTs, powered by the [cr-sqlite](https://github.com/vlcn-io/cr-sqlite) extension.

## How it works

cr-sqlite adds CRDT support at the SQLite level. Domain tables are marked as **CRRs** (Conflict-free Replicated Relations) — every column-level write is tracked with a Lamport clock. When two nodes make conflicting writes to the same field, last-writer-wins resolution happens automatically.

Changes are exchanged via a JSON HTTP API between peers. Each node maintains a **db_version watermark** per peer, so only new changes are sent on each push cycle.

## Architecture

```
Node A (SQLite + cr-sqlite)          Node B (SQLite + cr-sqlite)
  |                                    |
  |-- POST /replication/changes ------>|  (push changes since watermark)
  |<-- POST /replication/changes ------|  (pull changes from peer)
  |                                    |
  crsql_changes virtual table          crsql_changes virtual table
  (tracks all column-level writes)     (merges remote writes via CRDT)
```

## Setup

### 1. Fetch the cr-sqlite extension

```bash
bin/fetch-crsqlite
```

Downloads the correct prebuilt binary for your platform (macOS/Linux, arm64/x86_64) from the [vlcn-io/cr-sqlite GitHub releases](https://github.com/vlcn-io/cr-sqlite/releases) into `lib/crsqlite/`. This runs automatically during `bin/setup` for SQLite installations.

Override the version with `CRSQLITE_VERSION` env var (default: `0.16.3`).

### 2. Enable replication

```bash
REPLICATION_ENABLED=true bin/rails server
```

This:
- Loads the cr-sqlite extension on every SQLite connection
- Enables the `Replication::Trackable` after-commit hooks
- Starts the recurring `Replication::PushToAllPeersJob` (every 5 seconds)

Optional: set `REPLICATION_SITE_ID` to assign a stable site identifier (otherwise cr-sqlite generates a random one).

### 3. Register peers

```ruby
# On Node A — register Node B as a peer
peer = Replication::Peer.create!(
  name: "node-b",
  base_url: "https://node-b.example.com"
)
peer.auth_token # => "abc123..." (auto-generated, give this to Node B)

# On Node B — register Node A with Node A's auth_token
Replication::Peer.create!(
  name: "node-a",
  base_url: "https://node-a.example.com",
  auth_token: "abc123..."
)
```

Both nodes need each other registered as peers for bidirectional sync.

### 4. Run the CRR migration

```bash
REPLICATION_ENABLED=true bin/rails db:migrate
```

The `EnableCrsqliteCrrTables` migration marks domain tables as CRRs. It only runs when replication is enabled and the database adapter is SQLite.

## Configuration

| Env var | Purpose | Default |
|---------|---------|---------|
| `REPLICATION_ENABLED` | Enable/disable replication | `false` |
| `REPLICATION_SITE_ID` | Stable node identifier | Random (cr-sqlite generated) |
| `CRSQLITE_VERSION` | cr-sqlite release version | `0.16.3` |
| `CRSQLITE_EXTENSION_PATH` | Override extension file path | `lib/crsqlite/crsqlite` |

## API Endpoints

All endpoints live under `/replication/` (no account slug prefix).

### `GET /replication/changes?since_db_version=N&limit=1000`

Returns changes since the given db_version. Authenticated via HMAC.

### `POST /replication/changes`

Accepts a JSON array of changes to apply. Supports gzip `Content-Encoding`. Authenticated via HMAC.

### `GET /replication/health`

Returns site_id, current db_version, and per-peer lag/state. No authentication required.

## Authentication

Peers authenticate using HMAC-SHA256:

- `X-Replication-Peer-Id`: the peer's UUID
- `X-Replication-Signature`: `HMAC-SHA256(request_body, auth_token)`

## Synced vs. skipped tables

**Synced** (31 tables): accesses, accounts, account_cancellations, account_join_codes, action_text_rich_texts, active_storage_attachments, active_storage_blobs, assignments, board_publications, boards, card_goldnesses, card_not_nows, cards, closures, columns, comments, entropies, events, identities, mentions, notifications, notification_bundles, pins, reactions, steps, taggings, tags, users, watches, webhooks, webhook_delinquency_trackers

**Skipped** (node-local): sessions, magic_links, identity_access_tokens, search_records_*, solid_queue_*, solid_cache_*, solid_cable_*, account_exports, account_imports, storage_entries, storage_totals, filters, filter_*, push_subscriptions, account_external_id_sequences

## Failure handling

- Peers track `consecutive_failures`. After 10 consecutive failures, the peer enters `error` state and stops receiving pushes.
- `PushToPeerJob` retries with polynomial backoff (up to 5 attempts).
- The recurring `PushToAllPeersJob` (every 5s) acts as a backstop for missed after-commit triggers.
- Reset a peer: `peer.update!(state: :active, consecutive_failures: 0)`

## Deployment

### Docker

The `Dockerfile` runs `bin/fetch-crsqlite` during the build stage — the binary is baked into the image. No runtime download needed.

### Local dev

`bin/setup` fetches the binary automatically for non-MySQL setups.

## File inventory

```
config/initializers/replication.rb            # Feature flag + config module
config/initializers/crsqlite.rb               # Extension loader
bin/fetch-crsqlite                            # Platform-aware binary downloader

db/migrate/XXX_create_replication_peers.rb    # Peers table
db/migrate/XXX_enable_crsqlite_crr_tables.rb  # Mark tables as CRR

app/models/replication/peer.rb                # Peer management, circuit breaker
app/models/replication/change.rb              # crsql_changes queries, serialization
app/models/concerns/replication/trackable.rb  # after_commit hook

app/controllers/replication/changes_controller.rb   # GET/POST changes
app/controllers/replication/healths_controller.rb   # Health endpoint
app/controllers/concerns/replication/authentication.rb  # HMAC auth

app/jobs/replication/push_to_all_peers_job.rb  # Recurring fan-out
app/jobs/replication/push_to_peer_job.rb        # Per-peer push with retry
```

## Known limitations

- **ActiveStorage files**: Only metadata records sync, not file bytes. Attachments remain node-local.
- **Binary UUID transport**: Site IDs and PKs from `crsql_changes` are binary blobs, base64-encoded for JSON transport.
- **cr-sqlite maintenance**: The [vlcn-io/cr-sqlite](https://github.com/vlcn-io/cr-sqlite) project has had periods of slower development. Consider vendoring a known-good binary or building from source if release cadence is a concern.
