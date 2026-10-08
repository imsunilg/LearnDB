-- Day 46: document metadata. The file bytes live in storage (disk now, blob storage later); the database keeps the pointer.
SET search_path = learninsurancedb, public;

CREATE SEQUENCE IF NOT EXISTS seq_document_no START 1;

CREATE TABLE IF NOT EXISTS documents (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_no   VARCHAR(30)   NOT NULL DEFAULT ('DOC-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('seq_document_no')::text, 6, '0')),
    entity_type   VARCHAR(20)   NOT NULL,                 -- customer | policy | claim | proposal
    entity_id     BIGINT        NOT NULL,
    document_type VARCHAR(30)   NOT NULL,                 -- master data DOCUMENT_TYPE code
    file_name     VARCHAR(255)  NOT NULL,                 -- the name the user uploaded
    content_type  VARCHAR(100)  NOT NULL,
    file_size     BIGINT        NOT NULL,
    storage_key   VARCHAR(200)  NOT NULL,                 -- generated name on disk: never trust the uploaded name for paths
    checksum      VARCHAR(64)   NOT NULL,                 -- SHA-256 of the content (integrity, duplicate detection)
    description   VARCHAR(500),
    created_date  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by    VARCHAR(100)  NOT NULL DEFAULT 'system',
    modified_date TIMESTAMPTZ,
    modified_by   VARCHAR(100),
    is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_documents_no UNIQUE (document_no),
    CONSTRAINT uq_documents_storage UNIQUE (storage_key),
    CONSTRAINT ck_documents_entity CHECK (entity_type IN ('customer', 'policy', 'claim', 'proposal')),
    CONSTRAINT ck_documents_size CHECK (file_size > 0)
);

CREATE INDEX IF NOT EXISTS ix_documents_entity ON documents (entity_type, entity_id) WHERE is_active;
CREATE INDEX IF NOT EXISTS ix_documents_checksum ON documents (checksum);
