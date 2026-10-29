\timing on
\echo '--- 10,000 users (en_US) ---'
SELECT count(*) AS users, count(DISTINCT full_name) AS unique_names, count(DISTINCT email) AS unique_emails
  FROM generate_users('en_US', 1, 1, 10000);

\echo '--- 10,000 users (de_DE) ---'
SELECT count(*) AS users, count(DISTINCT full_name) AS unique_names, count(DISTINCT email) AS unique_emails
  FROM generate_users('de_DE', 1, 1, 10000);

\echo '--- 100,000 users (en_US) - may take from several seconds to a few dozen seconds ---'
SELECT count(*) AS users, count(DISTINCT full_name) AS unique_names, count(DISTINCT email) AS unique_emails,
       count(DISTINCT (full_name, address)) AS unique_name_address
  FROM generate_users('en_US', 1, 1, 100000);
