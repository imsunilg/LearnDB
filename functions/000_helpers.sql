-- Helper functions: snake_case <-> camelCase conversion so every function returns camelCase JSON.
SET search_path = learninsurancedb, public;

CREATE OR REPLACE FUNCTION fn_snake_to_camel(s text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT string_agg(CASE WHEN ord = 1 THEN part ELSE upper(left(part, 1)) || substr(part, 2) END, '' ORDER BY ord)
    FROM unnest(string_to_array(s, '_')) WITH ORDINALITY AS t(part, ord);
$$;

CREATE OR REPLACE FUNCTION fn_to_snake(s text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT lower(regexp_replace(s, '([A-Z])', '_\1', 'g'));
$$;

-- Recursively converts every object key of a jsonb document to camelCase.
CREATE OR REPLACE FUNCTION fn_to_camel(j jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    IF j IS NULL THEN
        RETURN NULL;
    ELSIF jsonb_typeof(j) = 'object' THEN
        RETURN COALESCE((SELECT jsonb_object_agg(learninsurancedb.fn_snake_to_camel(e.k), learninsurancedb.fn_to_camel(e.v)) FROM jsonb_each(j) AS e(k, v)), '{}'::jsonb);
    ELSIF jsonb_typeof(j) = 'array' THEN
        RETURN COALESCE((SELECT jsonb_agg(learninsurancedb.fn_to_camel(a.v) ORDER BY a.ord) FROM jsonb_array_elements(j) WITH ORDINALITY AS a(v, ord)), '[]'::jsonb);
    END IF;
    RETURN j;
END
$$;
