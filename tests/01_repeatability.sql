DO $$
DECLARE
    v_locale  TEXT;
    v_diff    INTEGER;
BEGIN
    FOREACH v_locale IN ARRAY ARRAY['en_US', 'de_DE'] LOOP
        SELECT COUNT(*) INTO v_diff FROM (
            SELECT * FROM generate_users(v_locale, 42, 3, 50)
            EXCEPT
            SELECT * FROM generate_users(v_locale, 42, 3, 50)
        ) x;
        IF v_diff <> 0 THEN
            RAISE EXCEPTION '[%] the same arguments produced different results', v_locale;
        END IF;

        SELECT COUNT(*) INTO v_diff FROM (
            SELECT full_name, address, email FROM generate_users(v_locale, 7, 2, 10) WHERE user_number = 15
            EXCEPT
            SELECT full_name, address, email FROM generate_users(v_locale, 7, 2, 100) WHERE user_number = 105
        ) x;
        IF v_diff <> 0 THEN
            RAISE EXCEPTION '[%] the result depends on batch size', v_locale;
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM generate_users(v_locale, 1, 1, 10) a
            JOIN generate_users(v_locale, 2, 1, 10) b USING (user_number)
            WHERE a.full_name <> b.full_name
        ) THEN
            RAISE EXCEPTION '[%] different seeds produced the same data', v_locale;
        END IF;

        IF (SELECT COUNT(*) FROM generate_users(v_locale, 1, 1, 10) a
            JOIN generate_users(v_locale, 1, 2, 10) b ON a.full_name = b.full_name) > 0 THEN
            RAISE EXCEPTION '[%] consecutive batches contain duplicates', v_locale;
        END IF;
    END LOOP;

    RAISE NOTICE 'REPEATABILITY TEST: OK';
END;
$$;
