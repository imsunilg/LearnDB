-- Seed product types and products (idempotent)
INSERT INTO learninsurancedb.insurance_product_types (code, name, description, icon, sort_order, created_by)
SELECT v.code, v.name, v.descr, v.icon, v.ord, 'seed'
FROM (VALUES
    ('MOTOR',  'Motor Insurance',  'Cars, two-wheelers and commercial vehicles',          '🚗', 1),
    ('HEALTH', 'Health Insurance', 'Individual and family medical cover',                 '❤️', 2),
    ('HOME',   'Home Insurance',   'Structure and contents cover for homes',              '🏠', 3),
    ('TRAVEL', 'Travel Insurance', 'Domestic and international trip protection',          '✈️', 4)
) AS v(code, name, descr, icon, ord)
WHERE NOT EXISTS (SELECT 1 FROM learninsurancedb.insurance_product_types t WHERE t.code = v.code);

INSERT INTO learninsurancedb.insurance_products
    (name, product_type_id, description, base_rate, min_sum_insured, max_sum_insured, effective_from, effective_to, created_by)
SELECT v.name, t.id, v.descr, v.rate, v.min_si, v.max_si, CURRENT_DATE + v.from_days, CASE WHEN v.to_days IS NULL THEN NULL ELSE CURRENT_DATE + v.to_days END, 'seed'
FROM (VALUES
    ('MOTOR',  'Private Car Comprehensive',   'Own damage + third party liability for private cars',      2.8500,   100000,  5000000, -400, NULL),
    ('MOTOR',  'Two Wheeler Comprehensive',   'Own damage + third party for bikes and scooters',          1.9500,    30000,   300000, -400, NULL),
    ('MOTOR',  'Commercial Vehicle Package',  'Goods and passenger carrying vehicles',                    3.4000,   200000,  3000000, -300, NULL),
    ('HEALTH', 'Individual Health Shield',    'Hospitalisation cover for one person',                     3.2000,   300000,  2500000, -500, NULL),
    ('HEALTH', 'Family Floater Plus',         'Single sum insured shared by the whole family',            3.8000,   500000,  5000000, -500, NULL),
    ('HEALTH', 'Senior Citizen Care',         'Cover for ages 60+ with pre-existing disease waiting',     5.5000,   200000,  1000000, -200, NULL),
    ('HOME',   'Home Structure Cover',        'Building cover against fire, flood and natural calamities',0.1800,  500000, 20000000, -365, NULL),
    ('HOME',   'Home Plus Contents',          'Structure plus household contents and valuables',          0.2600,  500000, 25000000, -365, NULL),
    ('HOME',   'Landlord Rental Cover',       'Rent protection and structure for landlords',              0.3200,  500000, 15000000,  -90, NULL),
    ('TRAVEL', 'Domestic Trip Protector',     'Delay, baggage loss and medical cover within India',       0.6500,    50000,   500000, -300, NULL),
    ('TRAVEL', 'International Explorer',      'Medical, baggage and trip cancellation abroad',            1.2000,   500000,  5000000, -300, NULL),
    ('TRAVEL', 'Student Overseas Cover',      'Annual cover for students studying abroad',                1.8000,  1000000, 10000000,  -30, 335)
) AS v(type_code, name, descr, rate, min_si, max_si, from_days, to_days)
JOIN learninsurancedb.insurance_product_types t ON t.code = v.type_code
WHERE NOT EXISTS (SELECT 1 FROM learninsurancedb.insurance_products p WHERE p.product_type_id = t.id AND lower(p.name) = lower(v.name));
