-- Health insurance rating factors (illustrative, idempotent)
INSERT INTO learninsurancedb.premium_rates (rate_group, rate_key, rate_value, unit, label, sort_order, created_by)
SELECT v.grp, v.key, v.val, v.unit, v.label, v.ord, 'seed'
FROM (VALUES
    ('HEALTH_AGE_FACTOR', '17', 0.60, 'factor', 'Up to 17', 1), ('HEALTH_AGE_FACTOR', '25', 0.80, 'factor', '18-25', 2),
    ('HEALTH_AGE_FACTOR', '35', 1.00, 'factor', '26-35', 3),    ('HEALTH_AGE_FACTOR', '45', 1.40, 'factor', '36-45', 4),
    ('HEALTH_AGE_FACTOR', '55', 2.00, 'factor', '46-55', 5),    ('HEALTH_AGE_FACTOR', '65', 3.00, 'factor', '56-65', 6),
    ('HEALTH_AGE_FACTOR', '99', 4.50, 'factor', 'Above 65', 7),
    ('HEALTH_LOADING', 'PRE_EXISTING', 15, 'percent', 'Pre-existing condition loading (% of member premium)', 1),
    ('HEALTH_LOADING', 'FLOATER_MEMBER', 20, 'percent', 'Floater: loading per additional member (% of eldest member premium)', 2),
    ('HEALTH_TERM_DISCOUNT', '2', 5, 'percent', '2-year term discount', 1),
    ('HEALTH_TERM_DISCOUNT', '3', 10, 'percent', '3-year term discount', 2)
) AS v(grp, key, val, unit, label, ord)
ON CONFLICT (rate_group, rate_key) DO NOTHING;
