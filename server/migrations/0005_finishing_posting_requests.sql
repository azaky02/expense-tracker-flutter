-- Server-owned immutable request identity. Not part of generic LWW sync.
CREATE TABLE IF NOT EXISTS finishing_posting_requests (
  user_id TEXT NOT NULL,
  event_id TEXT NOT NULL,
  payload_hash TEXT NOT NULL CHECK (length(payload_hash) = 64),
  state TEXT NOT NULL DEFAULT 'reserved'
    CHECK (state IN ('reserved','committed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  committed_at TIMESTAMPTZ,
  PRIMARY KEY (user_id, event_id),
  CHECK ((state = 'reserved' AND committed_at IS NULL) OR
         (state = 'committed' AND committed_at IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS idx_finishing_posting_requests_user_state
  ON finishing_posting_requests (user_id, state);
