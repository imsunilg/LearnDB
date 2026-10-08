-- Day 32: configuration-driven forms. Each row describes ONE input of a product line's proposal form.
-- The React form engine renders (and validates) whatever this table says - no UI release to add or change a question.
SET search_path = learninsurancedb, public;

CREATE TABLE IF NOT EXISTS product_field_config (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_type_code   VARCHAR(20)  NOT NULL REFERENCES insurance_product_types (code),
    parent_key          VARCHAR(100),                   -- set for children of a repeating 'group' field
    field_key           VARCHAR(100) NOT NULL,          -- path inside proposal.details, e.g. 'property.type' or 'members'
    label               VARCHAR(150) NOT NULL,
    field_type          VARCHAR(20)  NOT NULL,          -- text|email|tel|number|date|select|radio|checkbox|textarea|group
    value_type          VARCHAR(10)  NOT NULL DEFAULT 'string',   -- string | number (how select/radio values are sent)
    required            BOOLEAN      NOT NULL DEFAULT FALSE,
    section             VARCHAR(80),
    sort_order          INT          NOT NULL DEFAULT 0,
    options             JSONB,                          -- static options: [{"value":"OWNER","label":"Owner"}]
    master_type         VARCHAR(40),                    -- options from master data (e.g. STATE)
    value_key           VARCHAR(10)  NOT NULL DEFAULT 'name',   -- master data: store the item's name or its code
    parent_field        VARCHAR(100),                   -- cascading select: path of the parent select
    parent_master_type  VARCHAR(40),                    -- master type of the parent select (to resolve its id)
    show_if             JSONB,                          -- {"field":"cover.contentsCover","equals":true}
    validation          JSONB,                          -- {"min":0,"max":100,"pattern":"^\\d{6}$","message":"...","afterField":"trip.startDate","maxDays":180,"minAge":0,"maxAge":90,"minItems":1,"maxItems":6}
    default_value       VARCHAR(200),
    hint                VARCHAR(250),
    placeholder         VARCHAR(150),
    created_date        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by          VARCHAR(100) NOT NULL DEFAULT 'system',
    modified_date       TIMESTAMPTZ,
    modified_by         VARCHAR(100),
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_pfc_type CHECK (field_type IN ('text', 'email', 'tel', 'number', 'date', 'select', 'radio', 'checkbox', 'textarea', 'group')),
    CONSTRAINT ck_pfc_value_type CHECK (value_type IN ('string', 'number'))
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_pfc_key ON product_field_config (product_type_code, COALESCE(parent_key, ''), field_key);
CREATE INDEX IF NOT EXISTS ix_pfc_type_sort ON product_field_config (product_type_code, sort_order);

-- Added after the first release of the table (idempotent for existing databases)
ALTER TABLE product_field_config ADD COLUMN IF NOT EXISTS value_key VARCHAR(10) NOT NULL DEFAULT 'name';
