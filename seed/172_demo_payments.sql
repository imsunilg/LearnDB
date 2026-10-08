-- Demo payments for the seeded policies (idempotent: runs once). Most policies are paid; a few are unpaid / failed.
SET search_path = learninsurancedb, public;

DO $$
DECLARE
    r record;
    i int := 0;
    v_modes text[] := ARRAY['UPI', 'CARD', 'NETBANKING', 'UPI', 'CARD'];
    v_started jsonb;
    v_id bigint;
    v_state text;
BEGIN
    IF EXISTS (SELECT 1 FROM learninsurancedb.payments) OR NOT EXISTS (SELECT 1 FROM learninsurancedb.policies) THEN RETURN; END IF;
    PERFORM setval('learninsurancedb.seq_payment_no', 1, FALSE);
    PERFORM setval('learninsurancedb.seq_receipt_no', 1, FALSE);

    FOR r IN SELECT id, policy_no, issued_date FROM learninsurancedb.policies ORDER BY id LOOP
        i := i + 1;
        -- policy numbers 5 and 13 stay unpaid, 9 has a failed attempt and then a successful retry, 11 only a failed attempt
        v_state := CASE WHEN i IN (5, 13) THEN 'unpaid' WHEN i = 9 THEN 'retry' WHEN i = 11 THEN 'failed' ELSE 'paid' END;
        CONTINUE WHEN v_state = 'unpaid';

        IF v_state IN ('failed', 'retry') THEN
            v_started := learninsurancedb.fn_payment_start(r.id, 'CARD', NULL, 'seed-fail-' || r.id, 'agent');
            v_id := (v_started->'payment'->>'id')::bigint;
            PERFORM learninsurancedb.fn_payment_complete(v_id, FALSE, 'TXN-FAILED-' || r.id, '{"gateway":"MockPay","approved":false,"message":"Card declined by the issuing bank."}'::jsonb, 'agent');
            UPDATE learninsurancedb.payments SET created_date = r.issued_date + interval '1 hour' WHERE id = v_id;
        END IF;
        IF v_state IN ('paid', 'retry') THEN
            v_started := learninsurancedb.fn_payment_start(r.id, v_modes[1 + (i % 5)], NULL, 'seed-ok-' || r.id, 'agent');
            v_id := (v_started->'payment'->>'id')::bigint;
            PERFORM learninsurancedb.fn_payment_complete(v_id, TRUE, 'TXN' || upper(substr(md5(r.policy_no), 1, 10)), '{"gateway":"MockPay","approved":true,"message":"Payment successful."}'::jsonb, 'agent');
            UPDATE learninsurancedb.payments SET created_date = r.issued_date + interval '2 hours', paid_date = r.issued_date + interval '2 hours' WHERE id = v_id;
        END IF;
    END LOOP;
END $$;
