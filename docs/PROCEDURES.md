# Function Documentation

Note: in PostgreSQL, a "stored procedure" that returns a value is a **function** (`CREATE FUNCTION`).
A true `PROCEDURE` (called with `CALL`) does not return a result - therefore, we use it only
for maintenance tasks (`rebuild_dictionary_indexes`).

**Context key** (`p_context_key`) is the text `locale|seed|batch|index`, e.g. `de_DE|42|1|0`.
**Stream** (`p_stream`) is the name of an attribute (e.g. `first_name`) that gives each attribute its own numbers.

---
## 03_random.sql - Pseudorandom Generator

### build_context_key(p_locale TEXT, p_seed BIGINT, p_batch INTEGER, p_index INTEGER) → TEXT
Combines four values into one string. **Algorithm:** concatenation using the `|` separator.
```sql
SELECT build_context_key('de_DE', 42, 1, 0);   -- 'de_DE|42|1|0'
```

### random_uniform(p_context_key TEXT, p_stream TEXT, p_draw INTEGER DEFAULT 0) → DOUBLE PRECISION
A number in the range [0, 1). **Algorithm:** MD5 of the text `key|stream|draw_number`; the first 13 hexadecimal
characters (52 bits) → integer → division by 2^52. The same text always produces the same hash,
so this is a pure function of its arguments (`IMMUTABLE`).
```sql
SELECT random_uniform('de_DE|42|1|0', 'height');      -- always the same number
SELECT random_uniform('de_DE|42|1|0', 'height', 1);   -- a different number (second draw)
```

### random_int_between(p_context_key, p_stream, p_low INTEGER, p_high INTEGER, p_draw INTEGER DEFAULT 0) → INTEGER
An integer in [p_low, p_high]. **Algorithm:** `low + floor(u * (high - low + 1))`.
```sql
SELECT random_int_between('en_US|1|1|0', 'house_number', 1, 9999);
```

### random_chance(p_context_key, p_stream, p_probability DOUBLE PRECISION, p_draw INTEGER DEFAULT 0) → BOOLEAN
`TRUE` with the specified probability. **Algorithm:** `u < p_probability`.
```sql
SELECT random_chance('en_US|1|1|0', 'has_title', 0.15);
```

### fill_pattern(p_context_key, p_stream, p_pattern TEXT) → TEXT
Fills a pattern with digits: `#` → 0-9, `N` → 2-9, other characters remain unchanged. **Algorithm:** loop through the pattern's characters,
calling `random_int_between` for each, with the character position used as the draw number.
```sql
SELECT fill_pattern('en_US|1|1|0', 'phone_digits', '+1 (N##) N##-####');
```

---
## 04_distributions.sql

### random_normal(p_context_key, p_stream, p_mean DOUBLE PRECISION, p_stddev DOUBLE PRECISION) → DOUBLE PRECISION
A number from a normal distribution. **Algorithm (Box-Muller):** for two independent u1, u2 ∈ [0,1):
`z = sqrt(-2·ln(1-u1)) · cos(2π·u2)` (z has mean 0 and standard deviation 1), result = `mean + standard_deviation · z`.
`1-u1` instead of `u1` prevents `ln(0)`.
```sql
SELECT random_normal('de_DE|42|1|0', 'height', 180, 7);   -- e.g. 183.4
```

### random_point_on_sphere(p_context_key, p_stream) → TABLE(latitude, longitude) [degrees]
A point uniformly distributed over a sphere. **Algorithm:** Archimedes' theorem - the height `z` of a point on a unit sphere
is uniformly distributed over [-1, 1]. Therefore, `z = 2u1 - 1`, latitude = `arcsin(z)`, longitude = `360·u2 - 180`.
Generating latitude directly from [-90, 90] would make points denser near the poles.
```sql
SELECT * FROM random_point_on_sphere('de_DE|42|1|0', 'location');
```

---
## 05_dictionary_pickers.sql

| Function | Arguments | Returns | Algorithm |
|---|---|---|---|
| `get_dictionary_size(p_dictionary, p_locale, p_gender='U')` | dictionary name, locale, gender | INTEGER | read from `dictionary_sizes` (0 if missing) |
| `pick_first_name(ctx, stream, locale, gender)` | gender `M`/`F` | TEXT | position = `random_int_between(1, size)`, read by index `(locale, gender, position)` |
| `pick_last_name(ctx, stream, locale, gender)` | same as above | TEXT | same as above; if no last names exist for that gender, uses `U` (unisex) |
| `pick_street(ctx, stream, locale)` | | TEXT | random entry from the `streets` dictionary |
| `pick_city(ctx, stream, locale)` | | TABLE(city_name, region_name) | random entry from the `cities` dictionary |
| `pick_title(ctx, stream, locale, gender)` | | TEXT | random `OFFSET` in the small `titles` table; duplicated rows are more frequent |
| `pick_eye_color(ctx, stream, locale)` | | TEXT | "roulette wheel": a random point on a segment whose length is the sum of the weights; result = the first color whose cumulative sum exceeds it |
| `pick_email_domain(ctx, stream, locale)` | | TEXT | random `OFFSET` in `email_domains` |
| `pick_phone_pattern(ctx, stream, locale)` | | TEXT | random `OFFSET` in `phone_formats` |
| `pick_address_template(ctx, stream, locale, uses_apartment)` | BOOLEAN | TEXT | random `OFFSET` in `address_formats` |

```sql
SELECT pick_first_name('de_DE|42|1|0', 'first_name', 'de_DE', 'F');
SELECT * FROM pick_city('en_US|42|1|0', 'city', 'en_US');
SELECT pick_eye_color('en_US|42|1|0', 'eye_color', 'en_US');
```

---
## 06_formatting.sql

### make_ascii_slug(p_text TEXT) → TEXT
Text for the local part of an email address. **Algorithm:** lowercase → `ä→ae, ö→oe, ü→ue, ß→ss` → translate accented characters
(é→e, etc.) → remove everything except `a-z0-9`.
```sql
SELECT make_ascii_slug('Müller-Schmidt');   -- 'muellerschmidt'
```

### build_person_name(p_context_key, p_locale, p_gender) → TABLE(name_full, name_first, name_last)
**Name generation:** first and last names come from dictionaries for the locale and gender; a middle name is included in about 25% of cases
(different from the first name), and a title in about 15% (from the `titles` table); format is randomly selected from 1-4:
`First [Middle] Last` (1-2), `First M. Last` (3, middle-name initial), `Last, First [Middle]` (4, without a title).
```sql
SELECT * FROM build_person_name('de_DE|42|1|1', 'de_DE', 'M');
```

### build_address(p_context_key, p_locale) → TEXT
**Algorithm:** randomly decides whether the address includes an apartment (25%), selects a matching template from `address_formats`, chooses a street,
a city with a region, a house number (1..`house_number_max`), an apartment number (1-99), and a postal code (`fill_pattern`
using `locales.postal_pattern`), then replaces the placeholders `{street} {number} {apt} {city} {region} {postal}`.
```sql
SELECT build_address('en_US|42|1|0', 'en_US');
```

### build_phone(p_context_key, p_locale) → TEXT
Selects a pattern from `phone_formats` and fills it with digits (`fill_pattern`).
```sql
SELECT build_phone('de_DE|42|1|0', 'de_DE');   -- e.g. '+49 151 18719229'
```

### build_email(p_context_key, p_locale, p_first_name, p_last_name) → TEXT
**Algorithm:** 6 variants of the local part (`first.last`, `f.last`, `firstlast`, `first_last`,
`last.first`, `flast`) using `make_ascii_slug`; in about 35% of cases, a number from 1-999 is appended;
the domain is selected from `email_domains` for the given locale.
```sql
SELECT build_email('en_US|42|1|0', 'en_US', 'Anna', 'Müller');
```

---
## 07_generate_users.sql

### generate_single_user(p_locale TEXT, p_seed BIGINT, p_batch INTEGER, p_index INTEGER) → fake_user
One user. **Algorithm:** context key → gender (50/50) → first and last name → point on a sphere →
height and weight from `random_normal` (means and standard deviations from the `locales` table, separately for each gender; result clamped to
140-210 cm and 40-180 kg) → eye color → address, phone, email. An error is raised if the locale is unknown, `p_batch < 1`, or `p_index < 0`.
```sql
SELECT * FROM generate_single_user('en_US', 42, 1, 0);
```

### generate_users(p_locale TEXT, p_seed BIGINT, p_batch INTEGER, p_batch_size INTEGER DEFAULT 10) → TABLE
Main function. Columns: `user_number, full_name, address, latitude, longitude, height_cm, weight_kg,
eye_color, phone, email`. `user_number = (batch-1)·batch_size + index + 1`. Allowed batch size: 1-1,000,000.
Because the result depends only on `(locale, seed, batch, index)`, user number 15 is the same with a batch
of 10 and a batch of 100.
```sql
SELECT * FROM generate_users('de_DE', 42, 1, 10);
SELECT count(*) FROM generate_users('en_US', 1, 1, 100000);
```

---
## 01_schema.sql

### rebuild_dictionary_indexes() - PROCEDURE (`CALL`)
Numbers rows in `names`, `surnames`, `streets`, and `cities` (the `position` column 1..N within each locale and gender,
ordered by `id`) and refreshes the `dictionary_sizes` table. Call after every dictionary change.
```sql
CALL rebuild_dictionary_indexes();
```
