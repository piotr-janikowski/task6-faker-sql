CREATE TYPE fake_user AS (
    full_name   TEXT,
    address     TEXT,
    latitude    NUMERIC(9, 6),
    longitude   NUMERIC(9, 6),
    height_cm   NUMERIC(4, 1),
    weight_kg   NUMERIC(4, 1),
    eye_color   TEXT,
    phone       TEXT,
    email       TEXT
);

CREATE FUNCTION generate_single_user(
    p_locale  TEXT,
    p_seed    BIGINT,
    p_batch   INTEGER,
    p_index   INTEGER
) RETURNS fake_user
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_locale_settings  locales%ROWTYPE;
    v_context_key      TEXT;
    v_gender           CHAR(1);
    v_name_full        TEXT;
    v_name_first       TEXT;
    v_name_last        TEXT;
    v_latitude         DOUBLE PRECISION;
    v_longitude        DOUBLE PRECISION;
    v_height           DOUBLE PRECISION;
    v_weight           DOUBLE PRECISION;
BEGIN
    SELECT * INTO v_locale_settings FROM locales WHERE locale_code = p_locale;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Unknown locale: %', p_locale;
    END IF;
    IF p_batch < 1 OR p_index < 0 THEN
        RAISE EXCEPTION 'Batch number must be >= 1 and index must be >= 0 (received % and %)', p_batch, p_index;
    END IF;

    v_context_key := build_context_key(p_locale, p_seed, p_batch, p_index);
    v_gender := CASE WHEN random_chance(v_context_key, 'gender', 0.5) THEN 'M' ELSE 'F' END;

    SELECT n.name_full, n.name_first, n.name_last
      INTO v_name_full, v_name_first, v_name_last
      FROM build_person_name(v_context_key, p_locale, v_gender) n;

    SELECT p.latitude, p.longitude INTO v_latitude, v_longitude
      FROM random_point_on_sphere(v_context_key, 'location') p;

    IF v_gender = 'M' THEN
        v_height := random_normal(v_context_key, 'height',
            v_locale_settings.height_mean_male::DOUBLE PRECISION, 
            v_locale_settings.height_stddev::DOUBLE PRECISION);
        v_weight := random_normal(v_context_key, 'weight',
            v_locale_settings.weight_mean_male::DOUBLE PRECISION,
            v_locale_settings.weight_stddev::DOUBLE PRECISION);
    ELSE
        v_height := random_normal(v_context_key, 'height',
            v_locale_settings.height_mean_female::DOUBLE PRECISION,
            v_locale_settings.height_stddev::DOUBLE PRECISION);
        v_weight := random_normal(v_context_key, 'weight',
            v_locale_settings.weight_mean_female::DOUBLE PRECISION,
            v_locale_settings.weight_stddev::DOUBLE PRECISION);
    END IF;
    v_height := GREATEST(140.0, LEAST(210.0, v_height));
    v_weight := GREATEST(40.0, LEAST(180.0, v_weight));

    RETURN (
        v_name_full,
        build_address(v_context_key, p_locale),
        round(v_latitude::NUMERIC, 6),
        round(v_longitude::NUMERIC, 6),
        round(v_height::NUMERIC, 1),
        round(v_weight::NUMERIC, 1),
        pick_eye_color(v_context_key, 'eye_color', p_locale),
        build_phone(v_context_key, p_locale),
        build_email(v_context_key, p_locale, v_name_first, v_name_last)
    )::fake_user;
END;
$$;

CREATE FUNCTION generate_users(
    p_locale      TEXT,
    p_seed        BIGINT,
    p_batch       INTEGER,
    p_batch_size  INTEGER DEFAULT 10
) RETURNS TABLE (
    user_number  BIGINT,
    full_name    TEXT,
    address      TEXT,
    latitude     NUMERIC,
    longitude    NUMERIC,
    height_cm    NUMERIC,
    weight_kg    NUMERIC,
    eye_color    TEXT,
    phone        TEXT,
    email        TEXT
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    IF p_batch_size < 1 OR p_batch_size > 1000000 THEN
        RAISE EXCEPTION 'Batch size must be between 1 and 1000000 (received %)', p_batch_size;
    END IF;

    RETURN QUERY
        SELECT (p_batch - 1)::BIGINT * p_batch_size + series.item_index + 1,
            u.full_name, u.address, u.latitude, u.longitude,
            u.height_cm, u.weight_kg, u.eye_color, u.phone, u.email
          FROM generate_series(0, p_batch_size - 1) AS series (item_index)
          CROSS JOIN LATERAL generate_single_user(p_locale, p_seed, p_batch, series.item_index) AS u
         ORDER BY series.item_index;
END;
$$;
