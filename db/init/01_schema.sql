CREATE TABLE locales (
    locale_code         TEXT PRIMARY KEY,
    display_name        TEXT NOT NULL,
    postal_pattern      TEXT NOT NULL,
    house_number_max    INTEGER NOT NULL,
    height_mean_male    NUMERIC NOT NULL,
    height_mean_female  NUMERIC NOT NULL,
    height_stddev       NUMERIC NOT NULL,
    weight_mean_male    NUMERIC NOT NULL,
    weight_mean_female  NUMERIC NOT NULL,
    weight_stddev       NUMERIC NOT NULL 
);

CREATE TABLE names (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    locale      TEXT NOT NULL REFERENCES locales (locale_code),
    gender      CHAR(1) NOT NULL CHECK (gender IN ('M', 'F')),
    name        TEXT NOT NULL,
    position    INTEGER,
    UNIQUE (locale, gender, name)
);
CREATE UNIQUE INDEX names_position_idx ON names (locale, gender, position);

CREATE TABLE surnames (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    locale      TEXT NOT NULL REFERENCES locales (locale_code),
    gender      CHAR(1) NOT NULL DEFAULT 'U' CHECK (gender IN ('M', 'F', 'U')),
    surname     TEXT NOT NULL,
    position    INTEGER,
    UNIQUE (locale, gender, surname)
);
CREATE UNIQUE INDEX surnames_position_idx ON surnames (locale, gender, position);

CREATE TABLE streets (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    locale       TEXT NOT NULL REFERENCES locales (locale_code),
    street_name  TEXT NOT NULL,
    position     INTEGER,
    UNIQUE (locale, street_name)
);
CREATE UNIQUE INDEX streets_position_idx ON streets (locale, position);

CREATE TABLE cities (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    locale      TEXT NOT NULL REFERENCES locales (locale_code),
    city        TEXT NOT NULL,
    region      TEXT NOT NULL,
    position    INTEGER,
    UNIQUE (locale, city)
);
CREATE UNIQUE INDEX cities_position_idx ON cities (locale, position);



CREATE TABLE titles (
    id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    locale  TEXT NOT NULL REFERENCES locales (locale_code),
    gender  CHAR(1) NOT NULL CHECK (gender IN ('M', 'F')),
    title   TEXT NOT NULL
);

CREATE TABLE eye_colors (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    locale      TEXT NOT NULL REFERENCES locales (locale_code),
    color_name  TEXT NOT NULL,
    weight      NUMERIC NOT NULL CHECK (weight > 0)
);

CREATE TABLE email_domains (
    id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    locale  TEXT NOT NULL REFERENCES locales (locale_code),
    domain  TEXT NOT NULL
);

CREATE TABLE phone_formats (
    id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    locale   TEXT NOT NULL REFERENCES locales (locale_code),
    pattern  TEXT NOT NULL
);

CREATE TABLE address_formats (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    locale          TEXT NOT NULL REFERENCES locales (locale_code),
    uses_apartment  BOOLEAN NOT NULL,
    template        TEXT NOT NULL
);

CREATE TABLE dictionary_sizes (
    dictionary_name  TEXT NOT NULL,
    locale           TEXT NOT NULL,
    gender           CHAR(1) NOT NULL DEFAULT 'U',
    size             INTEGER NOT NULL,
    PRIMARY KEY (dictionary_name, locale, gender)
);


CREATE PROCEDURE rebuild_dictionary_indexes()
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE names    SET position = NULL;
    UPDATE surnames SET position = NULL;
    UPDATE streets  SET position = NULL;
    UPDATE cities   SET position = NULL;

    UPDATE names t SET position = numbered.new_position
    FROM (SELECT id, ROW_NUMBER() OVER (PARTITION BY locale, gender ORDER BY id) AS new_position
          FROM names) numbered
    WHERE t.id = numbered.id;

    UPDATE surnames t SET position = numbered.new_position
    FROM (SELECT id, ROW_NUMBER() OVER (PARTITION BY locale, gender ORDER BY id) AS new_position
          FROM surnames) numbered
    WHERE t.id = numbered.id;

    UPDATE streets t SET position = numbered.new_position
    FROM (SELECT id, ROW_NUMBER() OVER (PARTITION BY locale ORDER BY id) AS new_position
          FROM streets) numbered
    WHERE t.id = numbered.id;

    UPDATE cities t SET position = numbered.new_position
    FROM (SELECT id, ROW_NUMBER() OVER (PARTITION BY locale ORDER BY id) AS new_position
          FROM cities) numbered
    WHERE t.id = numbered.id;

    DELETE FROM dictionary_sizes;
    INSERT INTO dictionary_sizes (dictionary_name, locale, gender, size)
        SELECT 'names', locale, gender, COUNT(*) FROM names GROUP BY locale, gender;
    INSERT INTO dictionary_sizes (dictionary_name, locale, gender, size)
        SELECT 'surnames', locale, gender, COUNT(*) FROM surnames GROUP BY locale, gender;
    INSERT INTO dictionary_sizes (dictionary_name, locale, gender, size)
        SELECT 'streets', locale, 'U', COUNT(*) FROM streets GROUP BY locale;
    INSERT INTO dictionary_sizes (dictionary_name, locale, gender, size)
        SELECT 'cities', locale, 'U', COUNT(*) FROM cities GROUP BY locale;
END;
$$;
