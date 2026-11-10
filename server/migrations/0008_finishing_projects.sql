-- Finishing project metadata is owned by the authenticated Masarefy user.
-- Multiple projects may belong to the same client; no uniqueness on client name.
CREATE TABLE finishing_projects (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  project_id text NOT NULL CHECK (project_id ~ '^[A-Za-z0-9_-]{1,100}$'),
  client_name text NOT NULL CHECK (length(trim(client_name)) BETWEEN 1 AND 150),
  project_name text NOT NULL CHECK (length(trim(project_name)) BETWEEN 1 AND 150),
  description text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id,project_id),
  FOREIGN KEY (user_id,project_id)
    REFERENCES finishing_project_balances(user_id,project_id)
);
CREATE INDEX finishing_projects_client_idx ON finishing_projects(user_id,client_name);
