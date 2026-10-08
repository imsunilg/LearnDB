-- Day 48/49: reporting. One round trip returns every number the dashboard and reports page need.
SET search_path = learninsurancedb, public;

CREATE OR REPLACE FUNCTION fn_report_dashboard(p_from date DEFAULT NULL, p_to date DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_from date := COALESCE(p_from, (CURRENT_DATE - INTERVAL '11 months')::date - (EXTRACT(day FROM CURRENT_DATE)::int - 1));
    v_to   date := COALESCE(p_to, CURRENT_DATE);
    r jsonb;
BEGIN
    SELECT jsonb_build_object(
        'from', v_from, 'to', v_to,
        'kpis', jsonb_build_object(
            'activePolicies',   (SELECT count(*) FROM learninsurancedb.policies WHERE is_active AND status = 'Active' AND end_date >= CURRENT_DATE),
            'policiesIssued',   (SELECT count(*) FROM learninsurancedb.policies WHERE is_active AND issued_date::date BETWEEN v_from AND v_to),
            'premiumWritten',   (SELECT COALESCE(sum(total_premium), 0) FROM learninsurancedb.policies WHERE is_active AND issued_date::date BETWEEN v_from AND v_to),
            'premiumCollected', (SELECT COALESCE(sum(amount), 0) FROM learninsurancedb.payments WHERE status = 'Success' AND paid_date::date BETWEEN v_from AND v_to),
            'outstanding',      (SELECT COALESCE(sum(learninsurancedb.fn_policy_amount_due(id)), 0) FROM learninsurancedb.policies WHERE is_active AND status = 'Active'),
            'customers',        (SELECT count(*) FROM learninsurancedb.customers WHERE is_active),
            'openClaims',       (SELECT count(*) FROM learninsurancedb.claims WHERE is_active AND status IN ('Intimated', 'Under Review', 'Documents Pending')),
            'claimsPaid',       (SELECT COALESCE(sum(approved_amount), 0) FROM learninsurancedb.claims WHERE is_active AND status = 'Settled' AND intimation_date BETWEEN v_from AND v_to),
            'expiring30',       (SELECT count(*) FROM learninsurancedb.policies WHERE is_active AND status = 'Active' AND end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 30),
            'pendingProposals', (SELECT count(*) FROM learninsurancedb.proposals WHERE is_active AND status IN ('Draft', 'Submitted', 'Under Review'))
        ),
        'premiumByMonth', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('month', to_char(m, 'Mon YY'), 'premium', COALESCE(s.premium, 0), 'policies', COALESCE(s.cnt, 0), 'collected', COALESCE(c.collected, 0)) ORDER BY m)
            FROM generate_series(date_trunc('month', v_from), date_trunc('month', v_to), interval '1 month') m
            LEFT JOIN (SELECT date_trunc('month', issued_date) mm, sum(total_premium) premium, count(*) cnt FROM learninsurancedb.policies WHERE is_active GROUP BY 1) s ON s.mm = m
            LEFT JOIN (SELECT date_trunc('month', paid_date) mm, sum(amount) collected FROM learninsurancedb.payments WHERE status = 'Success' GROUP BY 1) c ON c.mm = m
        ), '[]'::jsonb),
        'byProductType', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('code', code, 'name', name, 'icon', icon, 'policies', cnt, 'premium', premium) ORDER BY premium DESC)
            FROM (SELECT pt.code, pt.name, pt.icon, count(*) cnt, COALESCE(sum(p.total_premium), 0) premium
                  FROM learninsurancedb.policies p
                  JOIN learninsurancedb.insurance_products pr ON pr.id = p.product_id
                  JOIN learninsurancedb.insurance_product_types pt ON pt.id = pr.product_type_id
                  WHERE p.is_active AND p.issued_date::date BETWEEN v_from AND v_to GROUP BY 1, 2, 3) x
        ), '[]'::jsonb),
        'claimsByStatus', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('status', status, 'count', cnt, 'amount', amt) ORDER BY cnt DESC)
            FROM (SELECT status, count(*) cnt, COALESCE(sum(claimed_amount), 0) amt FROM learninsurancedb.claims WHERE is_active GROUP BY 1) x
        ), '[]'::jsonb),
        'paymentsByMode', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('mode', COALESCE(md.name, x.payment_mode), 'count', cnt, 'amount', amt) ORDER BY amt DESC)
            FROM (SELECT payment_mode, count(*) cnt, sum(amount) amt FROM learninsurancedb.payments WHERE status = 'Success' AND paid_date::date BETWEEN v_from AND v_to GROUP BY 1) x
            LEFT JOIN learninsurancedb.master_data md ON md.type = 'PAYMENT_MODE' AND md.code = x.payment_mode
        ), '[]'::jsonb),
        'policiesByStatus', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('status', status, 'count', cnt) ORDER BY cnt DESC)
            FROM (SELECT CASE WHEN status = 'Active' AND end_date < CURRENT_DATE THEN 'Expired' ELSE status END status, count(*) cnt
                  FROM learninsurancedb.policies WHERE is_active GROUP BY 1) x
        ), '[]'::jsonb),
        'topAgents', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('agent', agent, 'policies', cnt, 'premium', premium) ORDER BY premium DESC)
            FROM (SELECT COALESCE(a.full_name, 'Direct') agent, count(*) cnt, sum(p.total_premium) premium
                  FROM learninsurancedb.policies p LEFT JOIN learninsurancedb.agents a ON a.id = p.agent_id
                  WHERE p.is_active AND p.issued_date::date BETWEEN v_from AND v_to GROUP BY 1 ORDER BY premium DESC LIMIT 5) x
        ), '[]'::jsonb),
        'expiringSoon', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', id, 'policyNo', policy_no, 'customerName', customer_name, 'endDate', end_date, 'daysToExpiry', days_to_expiry) ORDER BY end_date)
            FROM (SELECT id, policy_no, customer_name, end_date, days_to_expiry FROM learninsurancedb.vw_policies
                  WHERE status = 'Active' AND end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 60 ORDER BY end_date LIMIT 8) x
        ), '[]'::jsonb)
    ) INTO r;
    RETURN learninsurancedb.fn_to_camel(r);
END
$$;
