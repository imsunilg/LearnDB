-- Day 46: register an uploaded file. list/get/delete are generated (functions/generated/document.sql).
SET search_path = learninsurancedb, public;

CREATE OR REPLACE FUNCTION fn_document_register(
    p_entity_type text, p_entity_id bigint, p_document_type text, p_file_name text, p_content_type text,
    p_file_size bigint, p_storage_key text, p_checksum text, p_description text, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    v_table text;
    v_ok boolean;
    v_id bigint;
BEGIN
    v_table := CASE p_entity_type WHEN 'customer' THEN 'customers' WHEN 'policy' THEN 'policies' WHEN 'claim' THEN 'claims' WHEN 'proposal' THEN 'proposals' END;
    IF v_table IS NULL THEN RAISE EXCEPTION 'Documents cannot be attached to a %', p_entity_type USING ERRCODE = 'P0001'; END IF;
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM learninsurancedb.%I WHERE id = $1)', v_table) INTO v_ok USING p_entity_id;
    IF NOT v_ok THEN RAISE EXCEPTION '% % was not found', initcap(p_entity_type), p_entity_id USING ERRCODE = 'P0002'; END IF;
    IF NOT EXISTS (SELECT 1 FROM learninsurancedb.master_data WHERE type = 'DOCUMENT_TYPE' AND code = p_document_type AND is_active) THEN
        RAISE EXCEPTION 'Unknown document type %', p_document_type USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO learninsurancedb.documents (entity_type, entity_id, document_type, file_name, content_type, file_size, storage_key, checksum, description, created_by)
    VALUES (p_entity_type, p_entity_id, p_document_type, p_file_name, p_content_type, p_file_size, p_storage_key, p_checksum, NULLIF(trim(p_description), ''), COALESCE(p_user, 'system'))
    RETURNING id INTO v_id;
    RETURN learninsurancedb.fn_document_get_by_id(v_id);
END
$$;
