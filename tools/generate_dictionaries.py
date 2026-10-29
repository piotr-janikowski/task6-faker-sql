import random
from pathlib import Path

from faker.providers.address import de_DE as address_de
from faker.providers.address import en_US as address_us
from faker.providers.person import de_DE as person_de
from faker.providers.person import en_US as person_us

rng = random.Random(20241028)

OUTPUT_FILE = Path(__file__).resolve().parent.parent / "db" / "init" / "02_dictionaries.sql"
ROWS_PER_INSERT = 500


def unique_list(values):
    return list(dict.fromkeys(values))


def sql_value(value):
    if isinstance(value, (bool, int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def insert_statements(table, columns, rows):
    statements = []
    column_list = ", ".join(columns)
    for start in range(0, len(rows), ROWS_PER_INSERT):
        chunk = rows[start:start + ROWS_PER_INSERT]
        values = ",\n".join("  (" + ", ".join(sql_value(v) for v in row) + ")" for row in chunk)
        statements.append(f"INSERT INTO {table} ({column_list}) VALUES\n{values};\n")
    return "".join(statements)


# 1. First and last names
us_first_male = unique_list(person_us.Provider.first_names_male)
us_first_female = unique_list(person_us.Provider.first_names_female)
us_last = unique_list(person_us.Provider.last_names)

de_first_male = unique_list(person_de.Provider.first_names_male)
de_first_female = unique_list(person_de.Provider.first_names_female)
de_last_base = unique_list(person_de.Provider.last_names)

de_last_double = []
while len(de_last_double) < 2000:
    first_part, second_part = rng.sample(de_last_base, 2)
    de_last_double.append(f"{first_part}-{second_part}")
de_last = unique_list(de_last_base + de_last_double)


# 2. Streets
NATURE_WORDS_EN = ["Oak", "Maple", "Pine", "Cedar", "Elm", "Birch", "Willow", "Cherry", "Walnut",
                   "Hickory", "Spruce", "Poplar", "Aspen", "Sunset", "Lake", "Hill", "Park",
                   "River", "Meadow", "Forest", "Ridge", "Valley", "Spring", "Church", "Mill",
                   "Main", "Market", "Washington", "Lincoln", "Jefferson", "Highland", "Prospect"]
STREET_SUFFIXES_EN = ["Street", "Avenue", "Road", "Lane", "Drive", "Court", "Boulevard", "Way",
                      "Place", "Terrace", "Circle", "Trail"]

def ordinal(number):
    if 10 <= number % 100 <= 20:
        suffix = "th"
    else:
        suffix = {1: "st", 2: "nd", 3: "rd"}.get(number % 10, "th")
    return f"{number}{suffix}"

us_streets = {f"{ordinal(n)} {rng.choice(STREET_SUFFIXES_EN)}" for n in range(1, 121)}
us_street_bases = us_last + NATURE_WORDS_EN
while len(us_streets) < 6000:
    us_streets.add(f"{rng.choice(us_street_bases)} {rng.choice(STREET_SUFFIXES_EN)}")
us_streets = sorted(us_streets)
rng.shuffle(us_streets)

NATURE_WORDS_DE = ["Haupt", "Bahnhof", "Schul", "Garten", "Linden", "Kirch", "Berg", "Wald", "Feld",
                   "Wiesen", "Rosen", "Birken", "Eichen", "Dorf", "Markt", "Mühlen", "Burg", "Park",
                   "Sonnen", "Goethe", "Schiller", "Lessing", "Bach", "Brunnen", "Gartenfeld",
                   "Industrie", "Friedhof", "Hof", "Tannen", "Buchen"]
STREET_SUFFIXES_DE = ["straße", "weg", "allee", "platz", "gasse", "ring"]

de_street_bases = [name for name in de_last_base if " " not in name and "-" not in name] + NATURE_WORDS_DE
de_streets = set()
for base in de_street_bases:
    for suffix in STREET_SUFFIXES_DE:
        de_streets.add(f"{base}{suffix}")
while len(de_streets) < 5000:
    first_name = rng.choice(de_first_male + de_first_female)
    last_name = rng.choice(de_last_base)
    de_streets.add(f"{first_name}-{last_name}-Straße")
de_streets = sorted(de_streets)
rng.shuffle(de_streets)


# 3. Cities (each city is assigned a region - a US state or a country)
us_states = list(address_us.Provider.states_abbr)
CITY_PREFIXES_US = list(address_us.Provider.city_prefixes)
CITY_SUFFIXES_US = list(address_us.Provider.city_suffixes)

us_city_names = set()
while len(us_city_names) < 4000:
    pattern = rng.randint(1, 4)
    first_name = rng.choice(us_first_male + us_first_female)
    last_name = rng.choice(us_last)
    prefix = rng.choice(CITY_PREFIXES_US)
    suffix = rng.choice(CITY_SUFFIXES_US)
    if pattern == 1:
        us_city_names.add(f"{prefix} {first_name}{suffix}")
    elif pattern == 2:
        us_city_names.add(f"{prefix} {first_name}")
    elif pattern == 3:
        us_city_names.add(f"{first_name}{suffix}")
    else:
        us_city_names.add(f"{last_name}{suffix}")
us_city_names = sorted(us_city_names)
rng.shuffle(us_city_names)

de_states = list(address_de.Provider.states)
de_cities_real = unique_list(address_de.Provider.cities)
DE_CITY_PARTS = ["Wald", "Berg", "Stein", "Bach", "Feld", "Brunn", "Linden", "Eichen", "Rosen", "Burg",
                 "Wiesen", "Tann", "Buch", "Moor", "Hagen"]
DE_CITY_ENDINGS = ["dorf", "hausen", "burg", "heim", "stadt", "bach", "feld", "ingen"]
DE_CITY_PREFIXES = ["", "Ober", "Nieder", "Neu", "Alt", "Bad "]
de_city_generated = unique_list(
    f"{prefix}{part.lower() if prefix and not prefix.endswith(' ') else part}{ending}"
    for prefix in DE_CITY_PREFIXES
    for part in DE_CITY_PARTS
    for ending in DE_CITY_ENDINGS
)
de_city_names = unique_list(de_cities_real + de_city_generated)

locales_rows = [
    ("en_US", "English (USA)", "#####", 9999, 175.3, 161.5, 7.2, 90.0, 77.0, 16.0),
    ("de_DE", "German (Germany)", "#####", 199, 180.3, 166.2, 7.0, 85.0, 68.0, 14.0),
]

titles_rows = [
    ("en_US", "M", "Mr."), ("en_US", "M", "Mr."), ("en_US", "M", "Dr."), ("en_US", "M", "Prof."), ("en_US", "M", "Rev."),
    ("en_US", "F", "Mrs."), ("en_US", "F", "Ms."), ("en_US", "F", "Miss"), ("en_US", "F", "Dr."), ("en_US", "F", "Prof."),
    ("de_DE", "M", "Herr"), ("de_DE", "M", "Dr."), ("de_DE", "M", "Prof."), ("de_DE", "M", "Prof. Dr."), ("de_DE", "M", "Dipl.-Ing."),
    ("de_DE", "F", "Frau"), ("de_DE", "F", "Dr."), ("de_DE", "F", "Prof."), ("de_DE", "F", "Prof. Dr."), ("de_DE", "F", "Dipl.-Ing."),
]

eye_colors_rows = [
    ("en_US", "brown", 45), ("en_US", "blue", 27), ("en_US", "hazel", 18), ("en_US", "green", 9), ("en_US", "gray", 1),
    ("de_DE", "braun", 35), ("de_DE", "blau", 40), ("de_DE", "grün", 10), ("de_DE", "grau", 10), ("de_DE", "haselnussbraun", 5),
]

email_domains_rows = (
    [("en_US", d) for d in ["gmail.com", "yahoo.com", "outlook.com", "hotmail.com", "icloud.com", "aol.com", "proton.me", "mail.com", "live.com", "comcast.net"]]
    + [("de_DE", d) for d in ["gmx.de", "web.de", "t-online.de", "gmail.com", "outlook.de", "freenet.de", "posteo.de", "icloud.com", "yahoo.de", "mail.de"]]
)

phone_patterns_rows = [
    ("en_US", "+1 (N##) N##-####"), ("en_US", "(N##) N##-####"), ("en_US", "N##-N##-####"),
    ("en_US", "+1 N## N## ####"), ("en_US", "N##.N##.####"), ("en_US", "1-N##-N##-####"),
    ("de_DE", "+49 151 ########"), ("de_DE", "+49 160 #######"), ("de_DE", "+49 170 #######"),
    ("de_DE", "0151 ########"), ("de_DE", "0176 #######"), ("de_DE", "+49 30 ########"),
    ("de_DE", "030 ########"), ("de_DE", "+49 89 #######"), ("de_DE", "040 ########"),
    ("de_DE", "0711 #######"),
]

address_formats_rows = [
    ("en_US", False, "{number} {street}, {city}, {region} {postal}"),
    ("en_US", False, "{number} {street}, {city} {region} {postal}"),
    ("en_US", False, "{number} {street}, {city}, {region}, {postal}"),
    ("en_US", True, "{number} {street}, Apt {apt}, {city}, {region} {postal}"),
    ("en_US", True, "{number} {street} Apt {apt}, {city}, {region} {postal}"),
    ("en_US", True, "{number} {street} #{apt}, {city}, {region} {postal}"),
    ("en_US", True, "{number} {street}, Unit {apt}, {city}, {region} {postal}"),
    ("de_DE", False, "{street} {number}, {postal} {city}"),
    ("de_DE", False, "{postal} {city}, {street} {number}"),
    ("de_DE", False, "{street} {number}, D-{postal} {city}"),
    ("de_DE", True, "{street} {number}, Wohnung {apt}, {postal} {city}"),
    ("de_DE", True, "{street} {number}, Whg. {apt}, {postal} {city}"),
    ("de_DE", True, "{street} {number}/{apt}, {postal} {city}"),
]


# 5. SQL
parts = [
    "-- ============================================================================\n"
    "-- File: db/init/02_dictionaries.sql\n"
    "-- NOTE: this file is GENERATED by tools/generate_dictionaries.py.\n"
    "-- Do not edit it manually - change the script and run it again.\n"
    "-- ============================================================================\n\n",
    insert_statements("locales", [
        "locale_code", "display_name", "postal_pattern", "house_number_max",
        "height_mean_male", "height_mean_female", "height_stddev",
        "weight_mean_male", "weight_mean_female", "weight_stddev"], locales_rows),
]

name_rows = ([("en_US", "M", n) for n in us_first_male] + [("en_US", "F", n) for n in us_first_female]
             + [("de_DE", "M", n) for n in de_first_male] + [("de_DE", "F", n) for n in de_first_female])
parts.append(insert_statements("names", ["locale", "gender", "name"], name_rows))

surname_rows = [("en_US", "U", n) for n in us_last] + [("de_DE", "U", n) for n in de_last]
parts.append(insert_statements("surnames", ["locale", "gender", "surname"], surname_rows))

street_rows = [("en_US", s) for s in us_streets] + [("de_DE", s) for s in de_streets]
parts.append(insert_statements("streets", ["locale", "street_name"], street_rows))

city_rows = ([("en_US", c, rng.choice(us_states)) for c in us_city_names]
             + [("de_DE", c, rng.choice(de_states)) for c in de_city_names])
parts.append(insert_statements("cities", ["locale", "city", "region"], city_rows))

parts.append(insert_statements("titles", ["locale", "gender", "title"], titles_rows))
parts.append(insert_statements("eye_colors", ["locale", "color_name", "weight"], eye_colors_rows))
parts.append(insert_statements("email_domains", ["locale", "domain"], email_domains_rows))
parts.append(insert_statements("phone_formats", ["locale", "pattern"], phone_patterns_rows))
parts.append(insert_statements("address_formats", ["locale", "uses_apartment", "template"],
                               address_formats_rows))

parts.append("\n-- Final step: number the rows (position column) and calculate dictionary sizes\n"
             "CALL rebuild_dictionary_indexes();\n")

OUTPUT_FILE.write_text("".join(parts), encoding="utf-8")

print(f"Saved {OUTPUT_FILE}")
print(f"  first names: en_US={len(us_first_male) + len(us_first_female)}, de_DE={len(de_first_male) + len(de_first_female)}")
print(f"  last names:  en_US={len(us_last)}, de_DE={len(de_last)}")
print(f"  streets:    en_US={len(us_streets)}, de_DE={len(de_streets)}")
print(f"  cities:     en_US={len(us_city_names)}, de_DE={len(de_city_names)}")
