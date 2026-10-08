-- Travel insurance rating factors (illustrative, idempotent)
INSERT INTO learninsurancedb.premium_rates (rate_group, rate_key, rate_value, unit, label, sort_order, created_by)
SELECT v.grp, v.key, v.val, v.unit, v.label, v.ord, 'seed'
FROM (VALUES
    ('TRAVEL_ZONE_FACTOR', 'DOMESTIC', 0.50, 'factor', 'Within India', 1), ('TRAVEL_ZONE_FACTOR', 'ASIA', 1.00, 'factor', 'Asia', 2),
    ('TRAVEL_ZONE_FACTOR', 'EUROPE', 1.80, 'factor', 'Europe / Schengen', 3), ('TRAVEL_ZONE_FACTOR', 'USA_CANADA', 2.50, 'factor', 'USA & Canada', 4),
    ('TRAVEL_ZONE_FACTOR', 'WORLDWIDE', 2.00, 'factor', 'Rest of the world', 5),
    -- share of the annual rate charged for a trip of N days (key = max days)
    ('TRAVEL_DURATION_FACTOR', '7', 0.06, 'factor', 'Up to 7 days', 1), ('TRAVEL_DURATION_FACTOR', '14', 0.10, 'factor', '8-14 days', 2),
    ('TRAVEL_DURATION_FACTOR', '30', 0.18, 'factor', '15-30 days', 3), ('TRAVEL_DURATION_FACTOR', '60', 0.30, 'factor', '31-60 days', 4),
    ('TRAVEL_DURATION_FACTOR', '180', 0.60, 'factor', '61-180 days', 5),
    -- traveller age loading (key = max age)
    ('TRAVEL_AGE_FACTOR', '17', 0.75, 'factor', 'Up to 17', 1), ('TRAVEL_AGE_FACTOR', '40', 1.00, 'factor', '18-40', 2),
    ('TRAVEL_AGE_FACTOR', '60', 1.50, 'factor', '41-60', 3),    ('TRAVEL_AGE_FACTOR', '70', 2.30, 'factor', '61-70', 4),
    ('TRAVEL_AGE_FACTOR', '99', 3.50, 'factor', 'Above 70', 5),
    ('TRAVEL_ADDON', 'ADVENTURE', 25, 'percent', 'Adventure sports cover (% of base)', 1),
    ('TRAVEL_DISCOUNT', 'GROUP', 5, 'percent', 'Group discount for 3+ travellers (% of base)', 1)
) AS v(grp, key, val, unit, label, ord)
ON CONFLICT (rate_group, rate_key) DO NOTHING;
