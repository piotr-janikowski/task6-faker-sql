\echo '--- Sphere: 20000 points ---'
SELECT round(avg((abs(latitude) < 30)::INT), 3)  AS share_band_pm30_expected_0_500,
       round(avg((latitude > 0)::INT), 3)        AS share_north_expected_0_500,
       round(avg((longitude > 0)::INT), 3)       AS share_east_expected_0_500
  FROM generate_users('en_US', 123, 1, 20000);

\echo '--- Normal distribution: height and weight (en_US) ---'
SELECT round(avg(height_cm), 1) AS avg_height, round(stddev(height_cm), 1) AS sd_height,
       round(avg(weight_kg), 1) AS avg_weight, round(stddev(weight_kg), 1) AS sd_weight
  FROM generate_users('en_US', 123, 1, 20000);

\echo '--- Eye colors (en_US): expected approx. 45/27/18/9/1% ---'
SELECT eye_color, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS percent
  FROM generate_users('en_US', 123, 1, 20000) GROUP BY eye_color ORDER BY percent DESC;
