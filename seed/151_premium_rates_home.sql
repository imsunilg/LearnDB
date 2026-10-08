-- Home insurance rating factors (illustrative, idempotent)
INSERT INTO learninsurancedb.premium_rates (rate_group, rate_key, rate_value, unit, label, sort_order, created_by)
SELECT v.grp, v.key, v.val, v.unit, v.label, v.ord, 'seed'
FROM (VALUES
    ('HOME_AGE_FACTOR', '5',  1.00, 'factor', 'Up to 5 years', 1), ('HOME_AGE_FACTOR', '15', 1.10, 'factor', '6-15 years', 2),
    ('HOME_AGE_FACTOR', '30', 1.25, 'factor', '16-30 years', 3),   ('HOME_AGE_FACTOR', '99', 1.50, 'factor', 'Over 30 years', 4),
    ('HOME_TYPE_FACTOR', 'APARTMENT', 0.90, 'factor', 'Apartment / Flat', 1),
    ('HOME_TYPE_FACTOR', 'INDEPENDENT_HOUSE', 1.00, 'factor', 'Independent house', 2),
    ('HOME_TYPE_FACTOR', 'VILLA', 1.15, 'factor', 'Villa', 3),
    ('HOME_CONSTRUCTION_FACTOR', 'RCC', 0.90, 'factor', 'RCC (concrete)', 1),
    ('HOME_CONSTRUCTION_FACTOR', 'BRICK', 1.00, 'factor', 'Brick & mortar', 2),
    ('HOME_CONSTRUCTION_FACTOR', 'OTHER', 1.30, 'factor', 'Other construction', 3),
    ('HOME_ADDON', 'CONTENTS', 0.25, 'percent', 'Household contents cover (% of contents value)', 1),
    ('HOME_ADDON', 'BURGLARY', 0.05, 'percent', 'Burglary & theft cover (% of sum insured)', 2),
    ('HOME_DISCOUNT', 'TENANT', 10, 'percent', 'Tenant discount (% of structure premium)', 1)
) AS v(grp, key, val, unit, label, ord)
ON CONFLICT (rate_group, rate_key) DO NOTHING;
