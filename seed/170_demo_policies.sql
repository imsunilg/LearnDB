-- Demo data: proposals → approved → issued policies with a spread of start dates so the search, renewal, claims,
-- payments and report screens have something to show (some expired, some expiring soon). Idempotent: runs once.
SET search_path = learninsurancedb, public;

CREATE OR REPLACE FUNCTION pg_temp.seed_policy(
    p_email text, p_product text, p_start date, p_term int, p_details text, p_agent_license text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_cust bigint; v_prod bigint; v_agent bigint; v_prop jsonb; v_pid bigint; v_pol jsonb;
BEGIN
    SELECT id INTO v_cust FROM learninsurancedb.customers WHERE email = p_email;
    SELECT id INTO v_prod FROM learninsurancedb.insurance_products WHERE name = p_product;
    SELECT id INTO v_agent FROM learninsurancedb.agents WHERE license_number = p_agent_license;
    IF v_cust IS NULL OR v_prod IS NULL THEN
        RAISE NOTICE 'seed_policy skipped: % / %', p_email, p_product; RETURN;
    END IF;

    v_prop := learninsurancedb.fn_proposal_save(NULL, jsonb_build_object('customerId', v_cust, 'productId', v_prod,
                'startDate', p_start, 'policyTermYears', p_term, 'agentId', v_agent, 'details', p_details::jsonb), 'seed');
    v_pid := (v_prop->>'id')::bigint;
    PERFORM learninsurancedb.fn_proposal_submit(v_pid, 'agent');
    PERFORM learninsurancedb.fn_proposal_change_status(v_pid, 'Approved', 'Approved (demo data)', 'underwriter');
    v_pol := learninsurancedb.fn_policy_create(v_pid, 'underwriter');

    -- make the history look real: issued the day before the policy starts
    UPDATE learninsurancedb.policies SET issued_date = p_start::timestamptz - interval '1 day', created_date = p_start::timestamptz - interval '1 day'
    WHERE id = (v_pol->>'id')::bigint;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM learninsurancedb.proposals WHERE created_by = 'seed') THEN
        RETURN;
    END IF;
    -- keep demo numbers starting at 1 when no real data exists yet
    IF NOT EXISTS (SELECT 1 FROM learninsurancedb.policies) THEN
        PERFORM setval('learninsurancedb.seq_policy_no', 1, FALSE);
        IF NOT EXISTS (SELECT 1 FROM learninsurancedb.proposals) THEN PERFORM setval('learninsurancedb.seq_proposal_no', 1, FALSE); END IF;
    END IF;

    -- MOTOR ---------------------------------------------------------------------------------------------------
    PERFORM pg_temp.seed_policy('aarav.sharma@example.com', 'Private Car Comprehensive', CURRENT_DATE - 340, 1,
        '{"vehicle":{"registrationNo":"MH12AB1234","vehicleType":"CAR","make":"Maruti Suzuki","model":"Swift","variant":"VXi","fuelType":"Petrol","manufactureYear":2021,"cubicCapacity":1197,"seatingCapacity":5},"insurance":{"idv":420000,"ncbPercent":20,"addOns":["ZERO_DEP","RSA"],"usage":"PRIVATE"}}', 'IRDA-AG-100001');
    PERFORM pg_temp.seed_policy('diya.patel@example.com', 'Private Car Comprehensive', CURRENT_DATE - 200, 1,
        '{"vehicle":{"registrationNo":"GJ01CD5678","vehicleType":"CAR","make":"Hyundai","model":"Creta","variant":"SX","fuelType":"Diesel","manufactureYear":2022,"cubicCapacity":1493,"seatingCapacity":5},"insurance":{"idv":900000,"ncbPercent":25,"addOns":["ZERO_DEP","ENGINE_PROTECT","RSA"],"usage":"PRIVATE"}}', 'IRDA-AG-100002');
    PERFORM pg_temp.seed_policy('rohan.mehta@example.com', 'Two Wheeler Comprehensive', CURRENT_DATE - 400, 1,
        '{"vehicle":{"registrationNo":"MH14EF9012","vehicleType":"TWO_WHEELER","make":"Honda","model":"Activa","variant":"6G","fuelType":"Petrol","manufactureYear":2020,"cubicCapacity":109,"seatingCapacity":2},"insurance":{"idv":48000,"ncbPercent":35,"addOns":["RSA"],"usage":"PRIVATE"}}', 'IRDA-AG-100007');
    PERFORM pg_temp.seed_policy('ananya.iyer@example.com', 'Private Car Comprehensive', CURRENT_DATE - 30, 1,
        '{"vehicle":{"registrationNo":"TN09GH3456","vehicleType":"CAR","make":"Tata Motors","model":"Nexon","variant":"XZ+","fuelType":"Electric","manufactureYear":2023,"cubicCapacity":1000,"seatingCapacity":5},"insurance":{"idv":780000,"ncbPercent":0,"addOns":["ZERO_DEP","RTI"],"usage":"PRIVATE"}}', 'IRDA-AG-100009');
    PERFORM pg_temp.seed_policy('vikram.singh@example.com', 'Private Car Comprehensive', CURRENT_DATE - 358, 1,
        '{"vehicle":{"registrationNo":"RJ14JK7890","vehicleType":"CAR","make":"Mahindra","model":"Thar","variant":"LX","fuelType":"Diesel","manufactureYear":2019,"cubicCapacity":2184,"seatingCapacity":4},"insurance":{"idv":720000,"ncbPercent":45,"addOns":["ENGINE_PROTECT"],"usage":"PRIVATE"}}', 'IRDA-AG-100003');
    PERFORM pg_temp.seed_policy('karthik.nair@example.com', 'Private Car Comprehensive', CURRENT_DATE - 100, 2,
        '{"vehicle":{"registrationNo":"KL07LM3344","vehicleType":"CAR","make":"Toyota","model":"Innova Crysta","variant":"GX","fuelType":"Diesel","manufactureYear":2018,"cubicCapacity":2393,"seatingCapacity":7},"insurance":{"idv":980000,"ncbPercent":50,"addOns":["ZERO_DEP","CONSUMABLES","RSA"],"usage":"PRIVATE"}}', 'IRDA-AG-100011');

    -- HOME ----------------------------------------------------------------------------------------------------
    PERFORM pg_temp.seed_policy('meera.joshi@example.com', 'Home Plus Contents', CURRENT_DATE - 170, 1,
        '{"property":{"type":"APARTMENT","constructionType":"RCC","ageYears":6,"ownership":"OWNER","builtUpArea":1100,"addressLine":"31 Deccan Gymkhana","state":"Maharashtra","city":"Pune","pincode":"411004"},"cover":{"buildingValue":4500000,"contentsCover":true,"contentsValue":600000,"burglaryCover":true}}', 'IRDA-AG-100007');
    PERFORM pg_temp.seed_policy('sanjay.gupta@example.com', 'Home Structure Cover', CURRENT_DATE - 351, 1,
        '{"property":{"type":"INDEPENDENT_HOUSE","constructionType":"BRICK","ageYears":22,"ownership":"OWNER","builtUpArea":2400,"addressLine":"90 Hazratganj","state":"Uttar Pradesh","city":"Lucknow","pincode":"226001"},"cover":{"buildingValue":7500000,"contentsCover":false,"burglaryCover":true}}', 'IRDA-AG-100012');
    PERFORM pg_temp.seed_policy('arjun.reddy@example.com', 'Home Plus Contents', CURRENT_DATE - 60, 1,
        '{"property":{"type":"VILLA","constructionType":"RCC","ageYears":3,"ownership":"OWNER","builtUpArea":3200,"addressLine":"14 Banjara Hills","state":"Telangana","city":"Hyderabad","pincode":"500034"},"cover":{"buildingValue":12000000,"contentsCover":true,"contentsValue":1500000,"burglaryCover":true}}', 'IRDA-AG-100005');

    -- HEALTH --------------------------------------------------------------------------------------------------
    PERFORM pg_temp.seed_policy('neha.kapoor@example.com', 'Individual Health Shield', CURRENT_DATE - 280, 1,
        '{"cover":{"planType":"INDIVIDUAL","sumInsured":500000},"members":[{"relationship":"Self","name":"Neha Kapoor","dateOfBirth":"1990-02-14","gender":"Female","preExisting":false}]}', 'IRDA-AG-100005');
    PERFORM pg_temp.seed_policy('rahul.khanna@example.com', 'Family Floater Plus', CURRENT_DATE - 120, 1,
        '{"cover":{"planType":"FLOATER","sumInsured":1000000},"members":[{"relationship":"Self","name":"Rahul Khanna","dateOfBirth":"1982-09-15","gender":"Male","preExisting":true,"conditions":[{"name":"Hypertension","sinceYears":3}]},{"relationship":"Spouse","name":"Anita Khanna","dateOfBirth":"1985-04-02","gender":"Female","preExisting":false},{"relationship":"Son","name":"Aryan Khanna","dateOfBirth":"2012-08-08","gender":"Male","preExisting":false}]}', 'IRDA-AG-100006');
    PERFORM pg_temp.seed_policy('kavya.menon@example.com', 'Individual Health Shield', CURRENT_DATE - 350, 1,
        '{"cover":{"planType":"INDIVIDUAL","sumInsured":300000},"members":[{"relationship":"Self","name":"Kavya Menon","dateOfBirth":"1996-11-11","gender":"Female","preExisting":false}]}', 'IRDA-AG-100009');
    PERFORM pg_temp.seed_policy('aditya.bansal@example.com', 'Family Floater Plus', CURRENT_DATE - 15, 2,
        '{"cover":{"planType":"FLOATER","sumInsured":2500000},"members":[{"relationship":"Self","name":"Aditya Bansal","dateOfBirth":"1989-06-21","gender":"Male","preExisting":false},{"relationship":"Spouse","name":"Preeti Bansal","dateOfBirth":"1991-01-19","gender":"Female","preExisting":false}]}', 'IRDA-AG-100001');

    -- TRAVEL --------------------------------------------------------------------------------------------------
    PERFORM pg_temp.seed_policy('sneha.kulkarni@example.com', 'International Explorer', CURRENT_DATE - 45, 1,
        '{"trip":{"destinationZone":"EUROPE","purpose":"LEISURE","startDate":"' || (CURRENT_DATE - 45) || '","endDate":"' || (CURRENT_DATE - 36) || '"},"travellers":[{"name":"Sneha Kulkarni","dateOfBirth":"1994-01-28","passportNo":"K1234567","relationship":"Self"}],"cover":{"sumInsured":1000000,"adventureSports":false}}', 'IRDA-AG-100006');
    PERFORM pg_temp.seed_policy('nikhil.desai@example.com', 'International Explorer', CURRENT_DATE + 20, 1,
        '{"trip":{"destinationZone":"USA_CANADA","purpose":"BUSINESS","startDate":"' || (CURRENT_DATE + 20) || '","endDate":"' || (CURRENT_DATE + 34) || '"},"travellers":[{"name":"Nikhil Desai","dateOfBirth":"1984-12-25","passportNo":"N7654321","relationship":"Self"},{"name":"Disha Desai","dateOfBirth":"1987-03-02","passportNo":"D1122334","relationship":"Spouse"}],"cover":{"sumInsured":2500000,"adventureSports":true}}', 'IRDA-AG-100006');
    PERFORM pg_temp.seed_policy('tanvi.rao@example.com', 'Domestic Trip Protector', CURRENT_DATE - 3, 1,
        '{"trip":{"destinationZone":"DOMESTIC","purpose":"LEISURE","startDate":"' || (CURRENT_DATE - 3) || '","endDate":"' || (CURRENT_DATE + 4) || '"},"travellers":[{"name":"Tanvi Rao","dateOfBirth":"1992-05-17","passportNo":"T1122110","relationship":"Self"}],"cover":{"sumInsured":100000,"adventureSports":false}}', 'IRDA-AG-100003');

    -- a few proposals in other states for the proposal screens
    PERFORM learninsurancedb.fn_proposal_save(NULL, jsonb_build_object('customerId', (SELECT id FROM learninsurancedb.customers WHERE email = 'ishita.das@example.com'),
        'productId', (SELECT id FROM learninsurancedb.insurance_products WHERE name = 'Two Wheeler Comprehensive'), 'startDate', CURRENT_DATE + 5, 'policyTermYears', 1,
        'details', '{"vehicle":{"registrationNo":"WB02NP5566","vehicleType":"TWO_WHEELER","make":"Bajaj","model":"Pulsar 150","fuelType":"Petrol","manufactureYear":2022,"cubicCapacity":149,"seatingCapacity":2},"insurance":{"idv":90000,"ncbPercent":20,"addOns":[],"usage":"PRIVATE"}}'::jsonb), 'seed');
END $$;

-- end dates of policies must reflect the shifted start dates (fn_policy_create already derived them from start_date + term)
