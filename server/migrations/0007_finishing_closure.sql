-- Project closure state is server-owned. All project posting paths must lock
-- the same balance row and reject financial_status='closed'.
ALTER TABLE finishing_project_balances
  ADD COLUMN financial_status text NOT NULL DEFAULT 'open'
    CHECK (financial_status IN ('open','closed')),
  ADD COLUMN closed_at timestamptz;

ALTER TABLE finishing_project_balances
  ADD CONSTRAINT finishing_closed_timestamp_consistency
  CHECK ((financial_status='open' AND closed_at IS NULL)
      OR (financial_status='closed' AND closed_at IS NOT NULL));

-- A reservation is project-scoped only after a posting flow supplies its project.
-- Existing reservations have no project association and must be reconciled
-- before any production use of project closure.
ALTER TABLE finishing_posting_requests ADD COLUMN project_id text;
CREATE INDEX finishing_posting_requests_pending_project_idx
  ON finishing_posting_requests(user_id,project_id)
  WHERE state='reserved';
