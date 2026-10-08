-- Demo claims in different workflow states (idempotent: runs once).
SET search_path = learninsurancedb, public;

CREATE OR REPLACE FUNCTION pg_temp.seed_claim(p_policy_no text, p_type text, p_days_ago int, p_amount numeric, p_desc text, p_steps jsonb DEFAULT '[]'::jsonb)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_pol bigint; v_claim jsonb; v_id bigint; s jsonb;
BEGIN
    SELECT id INTO v_pol FROM learninsurancedb.policies WHERE policy_no = p_policy_no;
    IF v_pol IS NULL THEN RAISE NOTICE 'claim skipped, policy % missing', p_policy_no; RETURN; END IF;
    v_claim := learninsurancedb.fn_claim_create(jsonb_build_object('policyId', v_pol, 'claimType', p_type, 'incidentDate', CURRENT_DATE - p_days_ago,
                'incidentLocation', 'Reported by customer', 'description', p_desc, 'claimedAmount', p_amount), 'agent');
    v_id := (v_claim->>'id')::bigint;
    FOR s IN SELECT * FROM jsonb_array_elements(p_steps) LOOP
        PERFORM learninsurancedb.fn_claim_change_status(v_id, s->>'to', s->>'remarks', NULLIF(s->>'amount', '')::numeric, 'claims');
    END LOOP;
    UPDATE learninsurancedb.claims SET intimation_date = (CURRENT_DATE - p_days_ago + 1)::timestamptz + interval '10 hours' WHERE id = v_id;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM learninsurancedb.claims) THEN RETURN; END IF;
    IF NOT EXISTS (SELECT 1 FROM learninsurancedb.policies) THEN RETURN; END IF;
    PERFORM setval('learninsurancedb.seq_claim_no', 1, FALSE);

    PERFORM pg_temp.seed_claim('POL-MOT-2026-000001', 'ACCIDENT', 40, 35000, 'Rear bumper and tail lamp damaged in a minor collision at a signal.',
        '[{"to":"Under Review"},{"to":"Documents Pending","remarks":"Please upload the repair estimate and the FIR copy"},{"to":"Under Review","remarks":"Documents received"},{"to":"Approved","amount":"30000","remarks":"Approved after surveyor report"},{"to":"Settled","remarks":"Paid to workshop"}]');
    PERFORM pg_temp.seed_claim('POL-MOT-2026-000002', 'THEFT', 12, 150000, 'Stereo, alloy wheels and battery stolen while the car was parked overnight.',
        '[{"to":"Under Review"}]');
    PERFORM pg_temp.seed_claim('POL-HEA-2026-000011', 'HOSPITALISATION', 25, 120000, 'Three-day hospitalisation for dengue treatment.',
        '[{"to":"Under Review"},{"to":"Approved","amount":"100000","remarks":"Room rent capped as per policy terms"}]');
    PERFORM pg_temp.seed_claim('POL-HOM-2026-000007', 'FIRE', 60, 400000, 'Short-circuit fire damaged the kitchen and part of the living room.',
        '[{"to":"Under Review"},{"to":"Rejected","remarks":"Cause attributed to unauthorised electrical modification (policy exclusion 4.2)"}]');
    PERFORM pg_temp.seed_claim('POL-HEA-2026-000010', 'HOSPITALISATION', 6, 60000, 'Emergency appendectomy.',
        '[{"to":"Documents Pending","remarks":"Discharge summary and original bills required"}]');
    PERFORM pg_temp.seed_claim('POL-MOT-2026-000004', 'ACCIDENT', 3, 78000, 'Side panel damage from a hit-and-run in a parking lot.');
END $$;
