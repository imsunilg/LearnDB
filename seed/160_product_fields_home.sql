-- Form definition of the HOME product line (idempotent)
INSERT INTO learninsurancedb.product_field_config
    (product_type_code, field_key, label, field_type, value_type, required, section, sort_order, options, master_type, parent_field, parent_master_type, show_if, validation, default_value, hint, placeholder, created_by)
SELECT 'HOME', v.key, v.label, v.type, v.vtype, v.required, v.section, v.ord, v.options::jsonb, v.master, v.parent_field, v.parent_master, v.show_if::jsonb, v.validation::jsonb, v.def, v.hint, v.placeholder, 'seed'
FROM (VALUES
    ('property.type',             'Property type',         'select',   'string', TRUE,  'Property', 10, NULL, 'PROPERTY_TYPE',     NULL, NULL, NULL, NULL, NULL, NULL, NULL),
    ('property.constructionType', 'Construction type',     'select',   'string', TRUE,  'Property', 20, NULL, 'CONSTRUCTION_TYPE', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
    ('property.ageYears',         'Age of property (years)','number',  'string', TRUE,  'Property', 30, NULL, NULL, NULL, NULL, NULL, '{"min":0,"max":100}', NULL, NULL, NULL),
    ('property.builtUpArea',      'Built-up area (sq ft)', 'number',   'string', TRUE,  'Property', 40, NULL, NULL, NULL, NULL, NULL, '{"min":100,"max":50000}', NULL, NULL, NULL),
    ('property.ownership',        'Ownership',             'radio',    'string', TRUE,  'Property', 50, '[{"value":"OWNER","label":"Owner"},{"value":"TENANT","label":"Tenant"}]', NULL, NULL, NULL, NULL, NULL, 'OWNER', NULL, NULL),
    ('property.addressLine',      'Address',               'text',     'string', TRUE,  'Property address', 60, NULL, NULL, NULL, NULL, NULL, '{"maxLength":250}', NULL, NULL, NULL),
    ('property.state',            'State',                 'select',   'string', TRUE,  'Property address', 70, NULL, 'STATE', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
    ('property.city',             'City',                  'select',   'string', TRUE,  'Property address', 80, NULL, 'CITY', 'property.state', 'STATE', NULL, NULL, NULL, NULL, NULL),
    ('property.pincode',          'Pincode',               'text',     'string', TRUE,  'Property address', 90, NULL, NULL, NULL, NULL, NULL, '{"pattern":"^\\d{6}$","message":"Pincode must be 6 digits"}', NULL, NULL, '400001'),
    ('cover.buildingValue',       'Building value (₹)',    'number',   'string', TRUE,  'Cover', 100, NULL, NULL, NULL, NULL, NULL, '{"min":100000}', NULL, 'Reconstruction cost of the structure', NULL),
    ('cover.contentsCover',       'Add household contents cover', 'checkbox', 'string', FALSE, 'Cover', 110, NULL, NULL, NULL, NULL, NULL, NULL, 'false', 'Furniture, appliances, valuables', NULL),
    ('cover.contentsValue',       'Contents value (₹)',    'number',   'string', TRUE,  'Cover', 120, NULL, NULL, NULL, NULL, '{"field":"cover.contentsCover","equals":true}', '{"min":10000,"max":5000000}', NULL, NULL, NULL),
    ('cover.burglaryCover',       'Burglary & theft cover','checkbox', 'string', FALSE, 'Cover', 130, NULL, NULL, NULL, NULL, NULL, NULL, 'true', NULL, NULL)
) AS v(key, label, type, vtype, required, section, ord, options, master, parent_field, parent_master, show_if, validation, def, hint, placeholder)
WHERE NOT EXISTS (
    SELECT 1 FROM learninsurancedb.product_field_config c
    WHERE c.product_type_code = 'HOME' AND c.parent_key IS NULL AND c.field_key = v.key);
