CREATE FUNCTION make_ascii_slug(p_text TEXT) RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$
    SELECT regexp_replace(
        translate(
            replace(replace(replace(replace(lower(p_text), 'ä', 'ae'), 'ö', 'oe'), 'ü', 'ue'), 'ß', 'ss'),
            'àáâãåçèéêëìíîïñòóôõøùúûýÿ',
            'aaaaaceeeeiiiinooooouuuyy'),
        '[^a-z0-9]', '', 'g');
$$;

CREATE FUNCTION build_person_name(
    p_context_key  TEXT,
    p_locale       TEXT,
    p_gender       CHAR(1)
) RETURNS TABLE (name_full TEXT, name_first TEXT, name_last TEXT)
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_first        TEXT;
    v_middle       TEXT;
    v_last         TEXT;
    v_title        TEXT;
    v_has_middle   BOOLEAN;
    v_has_title    BOOLEAN;
    v_format       INTEGER;
    v_given_names  TEXT;
    v_formatted    TEXT;
BEGIN
    v_first      := pick_first_name(p_context_key, 'first_name', p_locale, p_gender);
    v_last       := pick_last_name(p_context_key, 'last_name', p_locale, p_gender);
    v_has_middle := random_chance(p_context_key, 'has_middle_name', 0.25);
    v_has_title  := random_chance(p_context_key, 'has_title', 0.15);
    v_format     := random_int_between(p_context_key, 'name_format', 1, 4);

    v_given_names := v_first;
    IF v_has_middle THEN
        v_middle := pick_first_name(p_context_key, 'middle_name', p_locale, p_gender);
        IF v_middle = v_first THEN
            v_middle := pick_first_name(p_context_key, 'middle_name_retry', p_locale, p_gender);
        END IF;

        IF v_format = 3 THEN
            v_given_names := v_first || ' ' || left(v_middle, 1) || '.';
        ELSE
            v_given_names := v_first || ' ' || v_middle;
        END IF;
    END IF;

    IF v_format = 4 THEN
        v_formatted := v_last || ', ' || v_given_names;
    ELSE
        v_formatted := v_given_names || ' ' || v_last;
        IF v_has_title THEN
            v_title := pick_title(p_context_key, 'title', p_locale, p_gender);
            IF v_title <> '' THEN
                v_formatted := v_title || ' ' || v_formatted;
            END IF;
        END IF;
    END IF;

    RETURN QUERY SELECT v_formatted, v_first, v_last;
END;
$$;

CREATE FUNCTION build_address(
    p_context_key  TEXT,
    p_locale       TEXT
) RETURNS TEXT
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_locale_settings  locales%ROWTYPE;
    v_has_apartment    BOOLEAN;
    v_template         TEXT;
    v_street           TEXT;
    v_city             TEXT;
    v_region           TEXT;
    v_house_number     INTEGER;
    v_apartment        INTEGER;
    v_postal_code      TEXT;
BEGIN
    SELECT * INTO v_locale_settings FROM locales WHERE locale_code = p_locale;

    v_has_apartment := random_chance(p_context_key, 'has_apartment', 0.25);
    v_template      := pick_address_template(p_context_key, 'address_format', p_locale, v_has_apartment);
    v_street        := pick_street(p_context_key, 'street', p_locale);
    v_house_number  := random_int_between(p_context_key, 'house_number', 1, v_locale_settings.house_number_max);
    v_apartment     := random_int_between(p_context_key, 'apartment_number', 1, 99);
    v_postal_code   := fill_pattern(p_context_key, 'postal_code', v_locale_settings.postal_pattern);

    SELECT c.city_name, c.region_name INTO v_city, v_region
      FROM pick_city(p_context_key, 'city', p_locale) c;

    RETURN replace(replace(replace(replace(replace(replace(v_template,
        '{street}', v_street),
        '{number}', v_house_number::TEXT),
        '{apt}',    v_apartment::TEXT),
        '{city}',   v_city),
        '{region}', v_region),
        '{postal}', v_postal_code);
END;
$$;

CREATE FUNCTION build_phone(
    p_context_key  TEXT,
    p_locale       TEXT
) RETURNS TEXT
LANGUAGE sql STABLE
AS $$
    SELECT fill_pattern(p_context_key, 'phone_digits', pick_phone_pattern(p_context_key, 'phone_format', p_locale));
$$;

CREATE FUNCTION build_email(
    p_context_key  TEXT,
    p_locale       TEXT,
    p_first_name   TEXT,
    p_last_name    TEXT
) RETURNS TEXT
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_first      TEXT := make_ascii_slug(p_first_name);
    v_last       TEXT := make_ascii_slug(p_last_name);
    v_variant    INTEGER;
    v_local_part TEXT;
BEGIN
    v_variant := random_int_between(p_context_key, 'email_variant', 1, 6);

    v_local_part := CASE v_variant
        WHEN 1 THEN v_first || '.' || v_last
        WHEN 2 THEN left(v_first, 1) || '.' || v_last
        WHEN 3 THEN v_first || v_last
        WHEN 4 THEN v_first || '_' || v_last
        WHEN 5 THEN v_last || '.' || v_first
        ELSE left(v_first, 1) || v_last
    END;

    IF random_chance(p_context_key, 'email_has_number', 0.35) THEN
        v_local_part := v_local_part || random_int_between(p_context_key, 'email_number', 1, 999)::TEXT;
    END IF;

    RETURN v_local_part || '@' || pick_email_domain(p_context_key, 'email_domain', p_locale);
END;
$$;
