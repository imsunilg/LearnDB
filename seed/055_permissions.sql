-- Permission catalogue (idempotent). Keep in sync with seed/060_role_permissions.sql and the UI NAV_ITEMS.
SET search_path = learninsurancedb, public;

INSERT INTO permissions (key, module, action, description, created_by)
SELECT m || '.' || a, m, a, initcap(a) || ' ' || m, 'seed'
FROM unnest(ARRAY['customers','agents','brokers','products','masterdata','proposals','policies','claims','payments',
                  'documents','endorsements','renewals','users','roles','audit']) AS m
CROSS JOIN unnest(ARRAY['view','create','edit','delete']) AS a
ON CONFLICT (key) DO NOTHING;

INSERT INTO permissions (key, module, action, description, created_by) VALUES
    ('reports.view',    'reports',  'view',   'View reports and dashboards', 'seed'),
    ('admin.view',      'admin',    'view',   'Open the Administration area', 'seed'),
    ('policies.issue',  'policies', 'issue',  'Issue policies from approved proposals', 'seed'),
    ('claims.approve',  'claims',   'approve','Approve or reject claims', 'seed'),
    ('payments.refund', 'payments', 'refund', 'Refund payments', 'seed')
ON CONFLICT (key) DO NOTHING;
