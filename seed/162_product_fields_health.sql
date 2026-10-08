-- Form definition of the HEALTH product line (idempotent): members group with a NESTED conditions group.
INSERT INTO learninsurancedb.product_field_config
    (product_type_code, parent_key, field_key, label, field_type, value_type, required, section, sort_order, options, master_type, show_if, validation, default_value, hint, placeholder, created_by)
SELECT 'HEALTH', v.parent, v.key, v.label, v.type, v.vtype, v.required, v.section, v.ord, v.options::jsonb, v.master, v.show_if::jsonb, v.validation::jsonb, v.def, v.hint, v.placeholder, 'seed'
FROM (VALUES
    (NULL, 'cover.planType',   'Plan type', 'radio', 'string', TRUE, 'Cover', 10,
        '[{"value":"INDIVIDUAL","label":"Individual (each member has own cover)"},{"value":"FLOATER","label":"Family floater (one cover shared)"}]', NULL, NULL, NULL, 'INDIVIDUAL', NULL, NULL),
    (NULL, 'cover.sumInsured', 'Sum insured', 'select', 'number', TRUE, 'Cover', 20,
        '[{"value":"300000","label":"₹3,00,000"},{"value":"500000","label":"₹5,00,000"},{"value":"1000000","label":"₹10,00,000"},{"value":"2500000","label":"₹25,00,000"},{"value":"5000000","label":"₹50,00,000"}]', NULL, NULL, NULL, NULL, 'For a floater this amount is shared by all members', NULL),
    (NULL, 'members',          'Members', 'group', 'string', FALSE, 'Insured members', 30, NULL, NULL, NULL, '{"minItems":1,"maxItems":6}', NULL, NULL, NULL),
    ('members', 'relationship', 'Relationship', 'select', 'string', TRUE, NULL, 1, NULL, 'RELATIONSHIP', NULL, NULL, NULL, NULL, NULL),
    ('members', 'name',         'Full name', 'text', 'string', TRUE, NULL, 2, NULL, NULL, NULL, '{"maxLength":100}', NULL, NULL, NULL),
    ('members', 'dateOfBirth',  'Date of birth', 'date', 'string', TRUE, NULL, 3, NULL, NULL, NULL, '{"minAge":0,"maxAge":80,"message":"Members must be aged 0-80"}', NULL, NULL, NULL),
    ('members', 'gender',       'Gender', 'select', 'string', TRUE, NULL, 4, '[{"value":"Male","label":"Male"},{"value":"Female","label":"Female"},{"value":"Other","label":"Other"}]', NULL, NULL, NULL, NULL, NULL, NULL),
    ('members', 'preExisting',  'Has a pre-existing condition', 'checkbox', 'string', FALSE, NULL, 5, NULL, NULL, NULL, NULL, 'false', 'Adds a 15% loading for this member', NULL),
    ('members', 'conditions',   'Conditions', 'group', 'string', FALSE, NULL, 6, NULL, NULL, '{"field":"preExisting","equals":true}', '{"minItems":1,"maxItems":5}', NULL, NULL, NULL),
    ('conditions', 'name',       'Condition', 'text', 'string', TRUE, NULL, 1, NULL, NULL, NULL, '{"maxLength":100}', NULL, NULL, 'e.g. Diabetes'),
    ('conditions', 'sinceYears', 'Since (years)', 'number', 'string', TRUE, NULL, 2, NULL, NULL, NULL, '{"min":0,"max":60}', NULL, NULL, NULL)
) AS v(parent, key, label, type, vtype, required, section, ord, options, master, show_if, validation, def, hint, placeholder)
WHERE NOT EXISTS (
    SELECT 1 FROM learninsurancedb.product_field_config c
    WHERE c.product_type_code = 'HEALTH' AND COALESCE(c.parent_key, '') = COALESCE(v.parent, '') AND c.field_key = v.key);
