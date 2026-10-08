-- Day 50: write one audit row (read side is generated: fn_audit_log_get_all / get_by_id).
SET search_path = learninsurancedb, public;

CREATE OR REPLACE FUNCTION fn_audit_log_write(
    p_correlation_id text, p_user text, p_method text, p_path text, p_entity text, p_entity_id bigint, p_action text,
    p_status int, p_duration_ms int, p_ip text, p_user_agent text) RETURNS void
LANGUAGE sql AS $$
    INSERT INTO learninsurancedb.audit_logs (correlation_id, user_name, method, path, entity, entity_id, action, status_code, duration_ms, ip_address, user_agent, created_by)
    VALUES (left(p_correlation_id, 64), COALESCE(NULLIF(p_user, ''), 'anonymous'), p_method, left(p_path, 300), p_entity, p_entity_id, p_action, p_status, p_duration_ms, left(p_ip, 45), left(p_user_agent, 200), COALESCE(NULLIF(p_user, ''), 'system'));
$$;
