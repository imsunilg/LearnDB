// Entity definitions that drive gen-crud.mjs.
// columns: [dbColumn, jsonKey(camelCase), type, defaultSqlExpr?]  - type: text|int|bigint|numeric|bool|boolnull|date|timestamptz|jsonb
// Options: view (custom SELECT), extraSelect/joins (appended to SELECT t.*), skip: ['create','update'], search, filters, sortExtra
export const entities = [
  {
    key: 'customer',
    label: 'Customer',
    table: 'customers',
    columns: [
      ['full_name', 'fullName'],
      ['email', 'email'],
      ['mobile', 'mobile'],
      ['date_of_birth', 'dateOfBirth', 'date'],
      ['gender', 'gender'],
      ['pan_number', 'panNumber'],
      ['address_line', 'addressLine'],
      ['city', 'city'],
      ['state', 'state'],
      ['pincode', 'pincode'],
      ['kyc_status', 'kycStatus', 'text', "'Pending'"],
    ],
    search: ['customer_code', 'full_name', 'email', 'mobile', 'city', 'pan_number'],
    filters: ['kyc_status', 'city', 'state', 'gender'],
    sortExtra: ['customer_code'],
  },
  {
    key: 'agent',
    label: 'Agent',
    table: 'agents',
    columns: [
      ['full_name', 'fullName'],
      ['email', 'email'],
      ['mobile', 'mobile'],
      ['license_number', 'licenseNumber'],
      ['license_expiry_date', 'licenseExpiryDate', 'date'],
      ['commission_percent', 'commissionPercent', 'numeric', '10'],
      ['broker_id', 'brokerId', 'bigint'],
      ['city', 'city'],
      ['state', 'state'],
      ['status', 'status', 'text', "'Active'"],
      ['joined_date', 'joinedDate', 'date', 'CURRENT_DATE'],
    ],
    search: ['agent_code', 'full_name', 'email', 'mobile', 'license_number', 'city'],
    filters: ['status', 'city', 'state', 'broker_id'],
    sortExtra: ['agent_code'],
  },
  {
    // Day 20: create/update are hand-written (password hashing + role assignment) in functions/210_users.sql
    key: 'user',
    label: 'User',
    table: 'users',
    skip: ['create', 'update'],
    columns: [],
    view: `SELECT t.id, t.username, t.email, t.full_name, t.mobile, t.last_login_date, t.must_change_password, t.failed_login_count, t.locked_until,
       t.created_date, t.created_by, t.modified_date, t.modified_by, t.is_active,
       COALESCE((SELECT string_agg(r.name, ', ' ORDER BY r.name) FROM learninsurancedb.user_roles ur
                 JOIN learninsurancedb.roles r ON r.id = ur.role_id WHERE ur.user_id = t.id AND ur.is_active), '') AS role_names,
       COALESCE((SELECT jsonb_agg(ur.role_id ORDER BY ur.role_id) FROM learninsurancedb.user_roles ur
                 WHERE ur.user_id = t.id AND ur.is_active), '[]'::jsonb) AS role_ids
FROM learninsurancedb.users t`,
    search: ['username', 'email', 'full_name', 'mobile', 'role_names'],
    sortExtra: ['username', 'email', 'full_name', 'last_login_date', 'role_names'],
    defaultSort: 'full_name',
    defaultDir: 'ASC',
  },
  {
    key: 'role',
    label: 'Role',
    table: 'roles',
    columns: [
      ['name', 'name'],
      ['description', 'description'],
    ],
    extraSelect: `(SELECT count(*) FROM learninsurancedb.role_permissions rp WHERE rp.role_id = t.id AND rp.is_active) AS permission_count,
       (SELECT count(*) FROM learninsurancedb.user_roles ur WHERE ur.role_id = t.id AND ur.is_active) AS user_count`,
    search: ['name', 'description'],
    sortExtra: ['permission_count', 'user_count'],
    defaultSort: 'name',
    defaultDir: 'ASC',
  },
]
