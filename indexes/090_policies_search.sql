-- Day 40: indexes that back the policy search filters and sorts
SET search_path = learninsurancedb, public;

CREATE INDEX IF NOT EXISTS ix_policies_issued_date    ON policies (issued_date DESC);
CREATE INDEX IF NOT EXISTS ix_policies_start_date     ON policies (start_date);
CREATE INDEX IF NOT EXISTS ix_policies_total_premium  ON policies (total_premium);
CREATE INDEX IF NOT EXISTS ix_policies_broker         ON policies (broker_id);
-- "Expiring soon" (renewals) only ever looks at active policies ordered by end date: a small partial index
CREATE INDEX IF NOT EXISTS ix_policies_active_end     ON policies (end_date) WHERE status = 'Active';
CREATE INDEX IF NOT EXISTS ix_policies_customer_status ON policies (customer_id, status);
