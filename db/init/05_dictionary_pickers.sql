CREATE FUNCTION get_dictionary_size(
    p_dictionary  TEXT,
    p_locale      TEXT,
    p_gender      CHAR(1) DEFAULT 'U'
) RETURNS INTEGER
LANGUAGE sql STABLE
AS $$
    SELECT COALESCE(
        (SELECT size FROM dictionary_sizes
          WHERE dictionary_name = p_dictionary AND locale = p_locale AND gender = p_gender),
        0);
$$;

CREATE FUNCTION pick_first_name(
    p_context_key  TEXT,
    p_stream       TEXT,
    p_locale       TEXT,
    p_gender       CHAR(1)
) RETURNS TEXT
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_size    INTEGER;
    v_result  TEXT;
BEGIN
    v_size := get_dictionary_size('names', p_locale, p_gender);
    IF v_size = 0 THEN
        RAISE EXCEPTION 'No first names for locale % and gender %', p_locale, p_gender;
    END IF;

    SELECT n.name INTO v_result
      FROM names n
     WHERE n.locale = p_locale AND n.gender = p_gender
       AND n.position = random_int_between(p_context_key, p_stream, 1, v_size);
    RETURN v_result;
END;
$$;

CREATE FUNCTION pick_last_name(
    p_context_key  TEXT,
    p_stream       TEXT,
    p_locale       TEXT,
    p_gender       CHAR(1)
) RETURNS TEXT
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_gender_used  CHAR(1) := p_gender;
    v_size         INTEGER;
    v_result       TEXT;
BEGIN
    v_size := get_dictionary_size('surnames', p_locale, v_gender_used);
    IF v_size = 0 THEN
        v_gender_used := 'U';
        v_size := get_dictionary_size('surnames', p_locale, v_gender_used);
    END IF;
    IF v_size = 0 THEN
        RAISE EXCEPTION 'No last names for locale %', p_locale;
    END IF;

    SELECT s.surname INTO v_result
      FROM surnames s
     WHERE s.locale = p_locale AND s.gender = v_gender_used
       AND s.position = random_int_between(p_context_key, p_stream, 1, v_size);
    RETURN v_result;
END;
$$;

CREATE FUNCTION pick_street(
    p_context_key  TEXT,
    p_stream       TEXT,
    p_locale       TEXT
) RETURNS TEXT
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_size    INTEGER;
    v_result  TEXT;
BEGIN
    v_size := get_dictionary_size('streets', p_locale);
    IF v_size = 0 THEN
        RAISE EXCEPTION 'No streets for locale %', p_locale;
    END IF;

    SELECT s.street_name INTO v_result
      FROM streets s
     WHERE s.locale = p_locale
       AND s.position = random_int_between(p_context_key, p_stream, 1, v_size);
    RETURN v_result;
END;
$$;

CREATE FUNCTION pick_city(
    p_context_key  TEXT,
    p_stream       TEXT,
    p_locale       TEXT
) RETURNS TABLE (city_name TEXT, region_name TEXT)
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_size INTEGER;
BEGIN
    v_size := get_dictionary_size('cities', p_locale);
    IF v_size = 0 THEN
        RAISE EXCEPTION 'No cities for locale %', p_locale;
    END IF;

    RETURN QUERY
        SELECT c.city, c.region
          FROM cities c
         WHERE c.locale = p_locale
           AND c.position = random_int_between(p_context_key, p_stream, 1, v_size);
END;
$$;

CREATE FUNCTION pick_title(
    p_context_key  TEXT,
    p_stream       TEXT,
    p_locale       TEXT,
    p_gender       CHAR(1)
) RETURNS TEXT
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_count   INTEGER;
    v_result  TEXT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM titles WHERE locale = p_locale AND gender = p_gender;
    IF v_count = 0 THEN
        RETURN '';
    END IF;

    SELECT t.title INTO v_result
      FROM titles t
     WHERE t.locale = p_locale AND t.gender = p_gender
     ORDER BY t.id
     OFFSET random_int_between(p_context_key, p_stream, 0, v_count - 1) LIMIT 1;
    RETURN v_result;
END;
$$;

CREATE FUNCTION pick_eye_color(
    p_context_key  TEXT,
    p_stream       TEXT,
    p_locale       TEXT
) RETURNS TEXT
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_total_weight  NUMERIC;
    v_threshold     NUMERIC;
    v_result        TEXT;
BEGIN
    SELECT SUM(weight) INTO v_total_weight FROM eye_colors WHERE locale = p_locale;
    IF v_total_weight IS NULL THEN
        RAISE EXCEPTION 'No eye colors for locale %', p_locale;
    END IF;
    v_threshold := random_uniform(p_context_key, p_stream, 0)::NUMERIC * v_total_weight;

    SELECT cumulative.color_name INTO v_result
      FROM (SELECT color_name, SUM(weight) OVER (ORDER BY id) AS running_total
              FROM eye_colors WHERE locale = p_locale) cumulative
     WHERE cumulative.running_total > v_threshold
     ORDER BY cumulative.running_total
     LIMIT 1;
    RETURN v_result;
END;
$$;

CREATE FUNCTION pick_email_domain(
    p_context_key  TEXT,
    p_stream       TEXT,
    p_locale       TEXT
) RETURNS TEXT
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_count   INTEGER;
    v_result  TEXT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM email_domains WHERE locale = p_locale;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'No email domains for locale %', p_locale;
    END IF;

    SELECT d.domain INTO v_result
      FROM email_domains d
     WHERE d.locale = p_locale
     ORDER BY d.id
     OFFSET random_int_between(p_context_key, p_stream, 0, v_count - 1) LIMIT 1;
    RETURN v_result;
END;
$$;

CREATE FUNCTION pick_phone_pattern(
    p_context_key  TEXT,
    p_stream       TEXT,
    p_locale       TEXT
) RETURNS TEXT
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_count   INTEGER;
    v_result  TEXT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM phone_formats WHERE locale = p_locale;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'No phone formats for locale %', p_locale;
    END IF;

    SELECT f.pattern INTO v_result
      FROM phone_formats f
     WHERE f.locale = p_locale
     ORDER BY f.id
     OFFSET random_int_between(p_context_key, p_stream, 0, v_count - 1) LIMIT 1;
    RETURN v_result;
END;
$$;

CREATE FUNCTION pick_address_template(
    p_context_key      TEXT,
    p_stream           TEXT,
    p_locale           TEXT,
    p_uses_apartment   BOOLEAN
) RETURNS TEXT
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_count   INTEGER;
    v_result  TEXT;
BEGIN
    SELECT COUNT(*) INTO v_count
      FROM address_formats WHERE locale = p_locale AND uses_apartment = p_uses_apartment;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'No address templates for locale %', p_locale;
    END IF;

    SELECT f.template INTO v_result
      FROM address_formats f
     WHERE f.locale = p_locale AND f.uses_apartment = p_uses_apartment
     ORDER BY f.id
     OFFSET random_int_between(p_context_key, p_stream, 0, v_count - 1) LIMIT 1;
    RETURN v_result;
END;
$$;
