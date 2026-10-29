# Faker in SQL

A web application that generates random, fake personal contact data.
**All data generation takes place in PostgreSQL.**
Python (Flask + Jinja2) only displays the results.

## Requirements
- Docker Desktop (Windows/macOS) or Docker Engine + Compose plugin (Linux).

## Step-by-step setup
1. Extract the archive and enter the project folder:
   ```
   cd faker-sql
   ```
2. Start everything:
   ```
   docker compose up --build
   ```
   On the first startup, the database automatically loads all scripts from `db/init/`.
   Wait for the message `database system is ready to accept connections`.
3. Open <http://localhost:5000> in your browser.
4. Select a locale, enter a seed, and click **Generate**. **Next batch** displays the next
   10 people with the same parameters.

### Important: reloading SQL scripts
Scripts from `db/init/` run **only on the first startup with an empty database**.
If you change any `.sql` file, reset the database:

## Using SQL directly
```
docker compose exec db psql -U faker -d faker
faker=# SELECT * FROM generate_users('de_DE', 42, 1, 10);
```

## Tests
```
docker compose exec -T db psql -U faker -d faker -v ON_ERROR_STOP=1 -f /tests/01_repeatability.sql
docker compose exec -T db psql -U faker -d faker -v ON_ERROR_STOP=1 -f /tests/02_distributions.sql
docker compose exec -T db psql -U faker -d faker -v ON_ERROR_STOP=1 -f /tests/03_performance.sql
```
Test 03 generates, among other things, 100,000 users (about 1-2 minutes, depending on the computer).

## Adding a new country (locale)
1. Add a row to the `locales` table and rows (with the new `locale` value) to `names`, `surnames`,
   `streets`, `cities`, `titles`, `eye_colors`, `email_domains`, `phone_formats`, and `address_formats`.
   The easiest way is to extend `tools/generate_dictionaries.py` and run it again.
2. Call `CALL rebuild_dictionary_indexes();`.
3. The new locale will automatically appear in the form - the Flask code and SQL functions remain unchanged.

## Notes
- The data is fake: a city is randomly assigned to a region, and postal codes consist of random digits.
- First and last names come from the Faker library lists (MIT license); the script in `tools/` only uses them.
