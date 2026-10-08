-- Day 23: agents work under a broker (optional). Idempotent.
SET search_path = learninsurancedb, public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_agents_broker') THEN
        ALTER TABLE agents ADD CONSTRAINT fk_agents_broker FOREIGN KEY (broker_id) REFERENCES brokers (id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_agents_broker ON agents (broker_id);
