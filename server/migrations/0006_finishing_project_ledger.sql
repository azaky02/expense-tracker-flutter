-- Server-authoritative finishing project balances, stored in integer piasters.
-- Do not derive these balances from client-supplied snapshots.
CREATE TABLE finishing_project_balances (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  project_id text NOT NULL,
  custody_piasters bigint NOT NULL DEFAULT 0 CHECK (custody_piasters >= 0),
  receivable_piasters bigint NOT NULL DEFAULT 0 CHECK (receivable_piasters >= 0),
  cost_piasters bigint NOT NULL DEFAULT 0 CHECK (cost_piasters >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, project_id)
);
CREATE TABLE finishing_project_movements (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id text NOT NULL,
  project_id text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('client_advance','cost','reimburse_from_custody','client_repay_personal','return_custody')),
  amount_piasters bigint NOT NULL CHECK (amount_piasters > 0),
  custody_share_piasters bigint NOT NULL DEFAULT 0 CHECK (custody_share_piasters >= 0),
  personal_share_piasters bigint NOT NULL DEFAULT 0 CHECK (personal_share_piasters >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, event_id),
  FOREIGN KEY (user_id, project_id) REFERENCES finishing_project_balances(user_id, project_id)
);
CREATE INDEX finishing_project_movements_project_idx
 ON finishing_project_movements(user_id, project_id, created_at);
