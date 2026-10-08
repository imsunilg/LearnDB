-- Form definition of the TRAVEL product line (idempotent). Children of the 'travellers' group use parent_key = 'travellers'.
INSERT INTO learninsurancedb.product_field_config
    (product_type_code, parent_key, field_key, label, field_type, value_type, required, section, sort_order, options, master_type, show_if, validation, default_value, hint, placeholder, created_by)
SELECT 'TRAVEL', v.parent, v.key, v.label, v.type, v.vtype, v.required, v.section, v.ord, v.options::jsonb, v.master, v.show_if::jsonb, v.validation::jsonb, v.def, v.hint, v.placeholder, 'seed'
FROM (VALUES
    (NULL, 'trip.destinationZone', 'Destination',       'select', 'string', TRUE,  'Trip details', 10,
        '[{"value":"DOMESTIC","label":"Within India"},{"value":"ASIA","label":"Asia (excluding India)"},{"value":"EUROPE","label":"Europe / Schengen"},{"value":"USA_CANADA","label":"USA & Canada"},{"value":"WORLDWIDE","label":"Rest of the world"}]', NULL, NULL, NULL, NULL, NULL, NULL),
    (NULL, 'trip.purpose',         'Purpose of travel', 'select', 'string', TRUE,  'Trip details', 20,
        '[{"value":"LEISURE","label":"Leisure"},{"value":"BUSINESS","label":"Business"},{"value":"EDUCATION","label":"Education"},{"value":"MEDICAL","label":"Medical"}]', NULL, NULL, NULL, 'LEISURE', NULL, NULL),
    (NULL, 'trip.startDate',       'Departure date',    'date',   'string', TRUE,  'Trip details', 30, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
    (NULL, 'trip.endDate',         'Return date',       'date',   'string', TRUE,  'Trip details', 40, NULL, NULL, NULL, '{"afterField":"trip.startDate","maxDays":180,"message":"Return date must be on or after departure and within 180 days"}', NULL, 'Trips are covered for up to 180 days', NULL),
    (NULL, 'travellers',           'Travellers',        'group',  'string', FALSE, 'Travellers', 50, NULL, NULL, NULL, '{"minItems":1,"maxItems":6}', NULL, NULL, NULL),
    ('travellers', 'name',         'Full name (as on passport)', 'text', 'string', TRUE, NULL, 1, NULL, NULL, NULL, '{"maxLength":100}', NULL, NULL, NULL),
    ('travellers', 'dateOfBirth',  'Date of birth',     'date',   'string', TRUE,  NULL, 2, NULL, NULL, NULL, '{"minAge":0,"maxAge":80,"message":"Travellers must be aged 0-80"}', NULL, NULL, NULL),
    ('travellers', 'passportNo',   'Passport number',   'text',   'string', TRUE,  NULL, 3, NULL, NULL, NULL, '{"pattern":"^[A-Z][0-9]{7}$","message":"Passport number looks like A1234567"}', NULL, NULL, 'A1234567'),
    ('travellers', 'relationship', 'Relationship to you','select','string', TRUE,  NULL, 4, NULL, 'RELATIONSHIP', NULL, NULL, NULL, NULL, NULL),
    (NULL, 'cover.sumInsured',     'Cover per traveller','select', 'number', TRUE,  'Cover', 60,
        '[{"value":"50000","label":"₹50,000"},{"value":"100000","label":"₹1,00,000"},{"value":"500000","label":"₹5,00,000"},{"value":"1000000","label":"₹10,00,000"},{"value":"2500000","label":"₹25,00,000"},{"value":"5000000","label":"₹50,00,000"}]', NULL, NULL, NULL, NULL, 'Medical, baggage and trip-delay cover per traveller', NULL),
    (NULL, 'cover.adventureSports','Include adventure sports cover', 'checkbox', 'string', FALSE, 'Cover', 70, NULL, NULL, NULL, NULL, 'false', 'Skiing, scuba diving, trekking (+25%)', NULL)
) AS v(parent, key, label, type, vtype, required, section, ord, options, master, show_if, validation, def, hint, placeholder)
WHERE NOT EXISTS (
    SELECT 1 FROM learninsurancedb.product_field_config c
    WHERE c.product_type_code = 'TRAVEL' AND COALESCE(c.parent_key, '') = COALESCE(v.parent, '') AND c.field_key = v.key);
