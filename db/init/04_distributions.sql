-- z = sqrt(-2 * ln(u1)) * cos(2 * pi * u2)
CREATE FUNCTION random_normal(
    p_context_key  TEXT,
    p_stream       TEXT,
    p_mean         DOUBLE PRECISION,
    p_stddev       DOUBLE PRECISION
) RETURNS DOUBLE PRECISION
LANGUAGE sql IMMUTABLE
AS $$
    SELECT p_mean + p_stddev
           * sqrt(-2.0 * ln(1.0 - random_uniform(p_context_key, p_stream, 0)))
           * cos(2.0 * pi() * random_uniform(p_context_key, p_stream, 1));
$$;

CREATE FUNCTION random_point_on_sphere(
    p_context_key  TEXT,
    p_stream       TEXT
) RETURNS TABLE (latitude DOUBLE PRECISION, longitude DOUBLE PRECISION)
LANGUAGE sql IMMUTABLE
AS $$
    SELECT degrees(asin(2.0 * random_uniform(p_context_key, p_stream, 0) - 1.0)),
           360.0 * random_uniform(p_context_key, p_stream, 1) - 180.0;
$$;
