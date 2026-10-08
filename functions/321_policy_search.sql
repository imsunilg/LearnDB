-- Day 40: advanced policy search. Same envelope as every list function: { items, totalCount, page, pageSize } + facets.
SET search_path = learninsurancedb, public;

-- p_filters (all optional, camelCase):
--   effectiveStatus, productTypeCode, productId, customerId, agentId, brokerId
--   issuedFrom/issuedTo, startFrom/startTo, endFrom/endTo   (yyyy-mm-dd)
--   premiumMin/premiumMax, sumInsuredMin/sumInsuredMax
--   expiringInDays  (policies that are active and end within N days from today, not yet expired)
DROP FUNCTION IF EXISTS learninsurancedb.fn_policy_search(text, int, int, text, text, jsonb);
CREATE FUNCTION learninsurancedb.fn_policy_search(
    p_search    text  DEFAULT NULL,
    p_page      int   DEFAULT 1,
    p_page_size int   DEFAULT 10,
    p_sort_by   text  DEFAULT NULL,
    p_sort_dir  text  DEFAULT NULL,
    p_filters   jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_page   int := GREATEST(COALESCE(p_page, 1), 1);
    v_size   int := LEAST(GREATEST(COALESCE(p_page_size, 10), 1), 200);
    v_sort   text := learninsurancedb.fn_to_snake(p_sort_by);
    v_dir    text := CASE WHEN lower(COALESCE(p_sort_dir, 'desc')) = 'asc' THEN 'ASC' ELSE 'DESC' END;
    v_f      jsonb := COALESCE(p_filters, '{}'::jsonb);
    v_where  text := 'WHERE TRUE';
    v_like   text;
    v_total  bigint;
    v_items  jsonb;
    v_facets jsonb;
    v_days   int;
BEGIN
    IF v_sort IS NULL OR NOT (v_sort = ANY (ARRAY['policy_no','customer_name','product_name','total_premium','sum_insured','start_date','end_date',
                                                  'effective_status','days_to_expiry','issued_date','created_date'])) THEN
        v_sort := 'issued_date';
        IF p_sort_by IS NULL THEN v_dir := 'DESC'; END IF;
    END IF;

    IF p_search IS NOT NULL AND btrim(p_search) <> '' THEN
        v_like := '%' || btrim(p_search) || '%';
        v_where := v_where || format(' AND (policy_no ILIKE %1$L OR customer_name ILIKE %1$L OR customer_code ILIKE %1$L OR customer_mobile ILIKE %1$L OR product_name ILIKE %1$L OR proposal_no ILIKE %1$L)', v_like);
    END IF;

    -- equality filters (values are quoted with %L - never concatenated raw)
    IF NULLIF(v_f->>'effectiveStatus', '') IS NOT NULL THEN v_where := v_where || format(' AND effective_status = %L', v_f->>'effectiveStatus'); END IF;
    IF NULLIF(v_f->>'productTypeCode', '') IS NOT NULL THEN v_where := v_where || format(' AND product_type_code = %L', upper(v_f->>'productTypeCode')); END IF;
    IF NULLIF(v_f->>'productId', '')  IS NOT NULL THEN v_where := v_where || format(' AND product_id = %L::bigint',  v_f->>'productId');  END IF;
    IF NULLIF(v_f->>'customerId', '') IS NOT NULL THEN v_where := v_where || format(' AND customer_id = %L::bigint', v_f->>'customerId'); END IF;
    IF NULLIF(v_f->>'agentId', '')    IS NOT NULL THEN v_where := v_where || format(' AND agent_id = %L::bigint',    v_f->>'agentId');    END IF;
    IF NULLIF(v_f->>'brokerId', '')   IS NOT NULL THEN v_where := v_where || format(' AND broker_id = %L::bigint',   v_f->>'brokerId');   END IF;

    -- ranges
    IF NULLIF(v_f->>'issuedFrom', '') IS NOT NULL THEN v_where := v_where || format(' AND issued_date >= %L::date', v_f->>'issuedFrom'); END IF;
    IF NULLIF(v_f->>'issuedTo', '')   IS NOT NULL THEN v_where := v_where || format(' AND issued_date < (%L::date + 1)', v_f->>'issuedTo'); END IF;
    IF NULLIF(v_f->>'startFrom', '')  IS NOT NULL THEN v_where := v_where || format(' AND start_date >= %L::date', v_f->>'startFrom'); END IF;
    IF NULLIF(v_f->>'startTo', '')    IS NOT NULL THEN v_where := v_where || format(' AND start_date <= %L::date', v_f->>'startTo'); END IF;
    IF NULLIF(v_f->>'endFrom', '')    IS NOT NULL THEN v_where := v_where || format(' AND end_date >= %L::date', v_f->>'endFrom'); END IF;
    IF NULLIF(v_f->>'endTo', '')      IS NOT NULL THEN v_where := v_where || format(' AND end_date <= %L::date', v_f->>'endTo'); END IF;
    IF NULLIF(v_f->>'premiumMin', '') IS NOT NULL THEN v_where := v_where || format(' AND total_premium >= %L::numeric', v_f->>'premiumMin'); END IF;
    IF NULLIF(v_f->>'premiumMax', '') IS NOT NULL THEN v_where := v_where || format(' AND total_premium <= %L::numeric', v_f->>'premiumMax'); END IF;
    IF NULLIF(v_f->>'sumInsuredMin', '') IS NOT NULL THEN v_where := v_where || format(' AND sum_insured >= %L::numeric', v_f->>'sumInsuredMin'); END IF;
    IF NULLIF(v_f->>'sumInsuredMax', '') IS NOT NULL THEN v_where := v_where || format(' AND sum_insured <= %L::numeric', v_f->>'sumInsuredMax'); END IF;

    v_days := NULLIF(v_f->>'expiringInDays', '')::int;
    IF v_days IS NOT NULL THEN
        v_where := v_where || format(' AND effective_status = ''Active'' AND end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + %s', v_days);
    END IF;

    EXECUTE format('SELECT count(*) FROM learninsurancedb.vw_policies %s', v_where) INTO v_total;
    EXECUTE format(
        'SELECT COALESCE(jsonb_agg(learninsurancedb.fn_to_camel(to_jsonb(q))), ''[]''::jsonb)
         FROM (SELECT * FROM learninsurancedb.vw_policies %s ORDER BY %I %s, id DESC LIMIT %s OFFSET %s) q',
        v_where, v_sort, v_dir, v_size, (v_page - 1) * v_size) INTO v_items;

    -- facet counts for the SAME filters (so the UI can show "Active 12 · Expired 3")
    EXECUTE format(
        'SELECT COALESCE(jsonb_object_agg(effective_status, c), ''{}''::jsonb)
         FROM (SELECT effective_status, count(*) AS c FROM learninsurancedb.vw_policies %s GROUP BY effective_status) f', v_where) INTO v_facets;

    RETURN jsonb_build_object('items', v_items, 'totalCount', v_total, 'page', v_page, 'pageSize', v_size, 'facets', v_facets);
END
$$;
