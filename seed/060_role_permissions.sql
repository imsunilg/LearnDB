-- Permission catalogue + role → permission mapping (idempotent).
SET search_path = learninsurancedb, public;

DO $$
DECLARE
    modules text[] := ARRAY['customers','agents','brokers','products','masterdata','proposals','policies','claims','payments',
                            'documents','endorsements','renewals','users','roles','audit'];
    verbs   text[] := ARRAY['view','create','edit','delete'];
    all_perms text[] := ARRAY['reports.view','admin.view','policies.issue','claims.approve','payments.refund'];
    m text; v text;
    viewer_perms text[];
BEGIN
    FOREACH m IN ARRAY modules LOOP
        FOREACH v IN ARRAY verbs LOOP
            all_perms := all_perms || (m || '.' || v);
        END LOOP;
    END LOOP;

    viewer_perms := ARRAY['customers.view','agents.view','brokers.view','products.view','masterdata.view','proposals.view',
                          'policies.view','claims.view','payments.view','documents.view','endorsements.view','renewals.view','reports.view'];

    CREATE TEMP TABLE _map (role_name text, perms text[]) ON COMMIT DROP;
    INSERT INTO _map VALUES
        ('Admin', all_perms),
        ('Underwriter', ARRAY['customers.view','customers.create','customers.edit','agents.view','brokers.view','products.view','masterdata.view',
                              'proposals.view','proposals.create','proposals.edit','policies.view','policies.issue','endorsements.view','endorsements.create',
                              'endorsements.edit','renewals.view','renewals.create','renewals.edit','payments.view','documents.view','documents.create','reports.view']),
        ('Agent', ARRAY['customers.view','customers.create','customers.edit','products.view','masterdata.view','proposals.view','proposals.create',
                        'proposals.edit','policies.view','renewals.view','renewals.create','endorsements.view','endorsements.create','payments.view',
                        'payments.create','claims.view','claims.create','documents.view','documents.create']),
        ('ClaimsOfficer', ARRAY['customers.view','policies.view','masterdata.view','claims.view','claims.create','claims.edit','claims.approve',
                                'documents.view','documents.create','payments.view']),
        ('Viewer', viewer_perms);

    INSERT INTO learninsurancedb.role_permissions (role_id, permission, created_by)
    SELECT r.id, p, 'seed'
    FROM _map mp
    JOIN learninsurancedb.roles r ON r.name = mp.role_name
    CROSS JOIN LATERAL unnest(mp.perms) AS p
    ON CONFLICT (role_id, permission) DO NOTHING;
END $$;
