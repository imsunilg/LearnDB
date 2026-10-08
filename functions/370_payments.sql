-- Day 45: payment lifecycle (list/get generated: functions/generated/payment.sql). The gateway call itself happens in the API (mock gateway).
SET search_path = learninsurancedb, public;

-- Outstanding premium of a policy = total premium - successful payments
CREATE OR REPLACE FUNCTION fn_policy_amount_due(p_policy_id bigint) RETURNS numeric
LANGUAGE sql STABLE AS $$
    SELECT GREATEST(p.total_premium - COALESCE((SELECT sum(amount) FROM learninsurancedb.payments x WHERE x.policy_id = p.id AND x.status = 'Success'), 0), 0)
    FROM learninsurancedb.policies p WHERE p.id = p_policy_id;
$$;

-- Step 1: record a payment ATTEMPT (Pending). IDEMPOTENT: the same key returns the existing row instead of creating a new one.
-- Returns { payment, created } so the API knows whether to call the gateway.
CREATE OR REPLACE FUNCTION fn_payment_start(p_policy_id bigint, p_mode text, p_amount numeric, p_idempotency_key text, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    v_existing bigint;
    v_pol record;
    v_due numeric;
    v_id bigint;
    v_parent bigint;
BEGIN
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id INTO v_existing FROM learninsurancedb.payments WHERE idempotency_key = p_idempotency_key;
        IF FOUND THEN
            RETURN jsonb_build_object('created', FALSE, 'payment', learninsurancedb.fn_payment_get_by_id(v_existing));
        END IF;
    END IF;

    SELECT * INTO v_pol FROM learninsurancedb.policies WHERE id = p_policy_id AND is_active;
    IF NOT FOUND THEN RAISE EXCEPTION 'Policy not found' USING ERRCODE = 'P0002'; END IF;
    IF v_pol.status IN ('Cancelled', 'Lapsed') THEN RAISE EXCEPTION 'Payments cannot be taken for a % policy', lower(v_pol.status) USING ERRCODE = 'P0001'; END IF;

    v_due := learninsurancedb.fn_policy_amount_due(p_policy_id);
    IF v_due <= 0 THEN RAISE EXCEPTION 'This policy is already fully paid' USING ERRCODE = 'P0001'; END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN p_amount := v_due; END IF;
    IF p_amount > v_due THEN RAISE EXCEPTION 'The amount exceeds the premium due (%)', v_due USING ERRCODE = 'P0001'; END IF;
    IF NOT EXISTS (SELECT 1 FROM learninsurancedb.master_data WHERE type = 'PAYMENT_MODE' AND code = upper(p_mode) AND is_active) THEN
        RAISE EXCEPTION 'Unknown payment mode %', p_mode USING ERRCODE = 'P0001';
    END IF;

    -- link to the latest failed attempt (retry chain)
    SELECT id INTO v_parent FROM learninsurancedb.payments WHERE policy_id = p_policy_id AND status = 'Failed' ORDER BY id DESC LIMIT 1;

    INSERT INTO learninsurancedb.payments (policy_id, customer_id, amount, payment_mode, status, idempotency_key, parent_payment_id, created_by)
    VALUES (p_policy_id, v_pol.customer_id, p_amount, upper(p_mode), 'Pending', p_idempotency_key, v_parent, COALESCE(p_user, 'system'))
    RETURNING id INTO v_id;
    RETURN jsonb_build_object('created', TRUE, 'payment', learninsurancedb.fn_payment_get_by_id(v_id));
END
$$;

-- Step 2: store the gateway outcome. Success creates the receipt number.
CREATE OR REPLACE FUNCTION fn_payment_complete(p_id bigint, p_success boolean, p_transaction_ref text, p_gateway_response jsonb, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE s text;
BEGIN
    SELECT status INTO s FROM learninsurancedb.payments WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Payment % not found', p_id USING ERRCODE = 'P0002'; END IF;
    IF s <> 'Pending' THEN RAISE EXCEPTION 'This payment is already %', lower(s) USING ERRCODE = 'P0001'; END IF;

    UPDATE learninsurancedb.payments SET
        status = CASE WHEN p_success THEN 'Success' ELSE 'Failed' END,
        transaction_ref = p_transaction_ref, gateway_response = p_gateway_response,
        paid_date = CASE WHEN p_success THEN now() ELSE NULL END,
        receipt_no = CASE WHEN p_success THEN 'RCT-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('learninsurancedb.seq_receipt_no')::text, 6, '0') ELSE NULL END,
        modified_date = now(), modified_by = COALESCE(p_user, 'system')
    WHERE id = p_id;
    RETURN learninsurancedb.fn_payment_get_by_id(p_id);
END
$$;

CREATE OR REPLACE FUNCTION fn_payment_refund(p_id bigint, p_remarks text, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE s text;
BEGIN
    SELECT status INTO s FROM learninsurancedb.payments WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Payment % not found', p_id USING ERRCODE = 'P0002'; END IF;
    IF s <> 'Success' THEN RAISE EXCEPTION 'Only successful payments can be refunded' USING ERRCODE = 'P0001'; END IF;
    UPDATE learninsurancedb.payments SET status = 'Refunded', remarks = NULLIF(p_remarks, ''), modified_date = now(), modified_by = COALESCE(p_user, 'system') WHERE id = p_id;
    RETURN learninsurancedb.fn_payment_get_by_id(p_id);
END
$$;
