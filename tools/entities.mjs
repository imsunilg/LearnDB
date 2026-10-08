// Entity definitions that drive gen-crud.mjs.
// columns: [dbColumn, jsonKey(camelCase), type]  - type: text|int|bigint|numeric|bool|boolnull|date|timestamptz|jsonb
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
]
