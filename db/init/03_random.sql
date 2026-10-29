CREATE FUNCTION build_context_key(
    p_locale  TEXT,
    p_seed    BIGINT,
    p_batch   INTEGER,
    p_index   INTEGER
) RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$
    SELECT p_locale || '|' || p_seed || '|' || p_batch || '|' || p_index;
$$;

CREATE FUNCTION random_uniform(
    p_context_key  TEXT,
    p_stream       TEXT,
    p_draw         INTEGER DEFAULT 0
) RETURNS DOUBLE PRECISION
LANGUAGE sql IMMUTABLE
AS $$
    SELECT (('x' || substr(md5(p_context_key || '|' || p_stream || '|' || p_draw), 1, 13))::bit(52)::bigint)::DOUBLE PRECISION
           / 4503599627370496.0;
$$;

CREATE FUNCTION random_int_between(
    p_context_key  TEXT,
    p_stream       TEXT,
    p_low          INTEGER,
    p_high         INTEGER,
    p_draw         INTEGER DEFAULT 0
) RETURNS INTEGER
LANGUAGE sql IMMUTABLE
AS $$
    SELECT p_low + floor(random_uniform(p_context_key, p_stream, p_draw) * (p_high - p_low + 1))::INTEGER;
$$;

CREATE FUNCTION random_chance(
    p_context_key  TEXT,
    p_stream       TEXT,
    p_probability  DOUBLE PRECISION,
    p_draw         INTEGER DEFAULT 0
) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE
AS $$
    SELECT random_uniform(p_context_key, p_stream, p_draw) < p_probability;
$$;

CREATE FUNCTION fill_pattern(
    p_context_key  TEXT,
    p_stream       TEXT,
    p_pattern      TEXT
) RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
    v_result     TEXT := '';
    v_character  TEXT;
    v_position   INTEGER;
BEGIN
    FOR v_position IN 1 .. length(p_pattern) LOOP
        v_character := substr(p_pattern, v_position, 1);
        IF v_character = '#' THEN
            v_result := v_result || random_int_between(p_context_key, p_stream, 0, 9, v_position)::TEXT;
        ELSIF v_character = 'N' THEN
            v_result := v_result || random_int_between(p_context_key, p_stream, 2, 9, v_position)::TEXT;
        ELSE
            v_result := v_result || v_character;
        END IF;
    END LOOP;
    RETURN v_result;
END;
$$;
