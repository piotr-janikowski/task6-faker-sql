import os
import psycopg2
from flask import Flask, render_template, request

app = Flask(__name__)

BATCH_SIZE = 10
DEFAULT_LOCALE = "en_US"
DEFAULT_SEED = 42
MAX_SEED = 2 ** 63 - 1


def open_connection():
    return psycopg2.connect(
        host=os.environ.get("DB_HOST", "localhost"),
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ.get("DB_NAME", "faker"),
        user=os.environ.get("DB_USER", "faker"),
        password=os.environ.get("DB_PASSWORD", "faker"),
    )


def parse_whole_number(text, default, minimum, maximum, field_label, errors):
    try:
        number = int(text)
    except (TypeError, ValueError):
        errors.append(f"Field “{field_label}” must be an integer - using the value {default}.")
        return default
    if number < minimum or number > maximum:
        errors.append(f"Field “{field_label}” is outside the allowed range - using the value {default}.")
        return default
    return number


@app.route("/")
def index():
    errors = []
    seed = parse_whole_number(request.args.get("seed", str(DEFAULT_SEED)), DEFAULT_SEED, -MAX_SEED, MAX_SEED, "Seed", errors)
    batch = parse_whole_number(request.args.get("batch", "1"), 1, 1, 100_000_000, "Batch", errors)
    locale = request.args.get("locale", DEFAULT_LOCALE)
    users = []
    locales = []
    try:
        with open_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT locale_code, display_name FROM locales ORDER BY display_name")
                locales = cursor.fetchall()
                known_codes = [code for code, _ in locales]
                if locale not in known_codes:
                    errors.append(f"Unknown locale “{locale}” - using {DEFAULT_LOCALE}.")
                    locale = DEFAULT_LOCALE
                cursor.execute(
                    "SELECT user_number, full_name, address, latitude, longitude, "
                    "       height_cm, weight_kg, eye_color, phone, email "
                    "FROM generate_users(%s, %s::BIGINT, %s, %s)",
                    (locale, seed, batch, BATCH_SIZE),
                )
                users = cursor.fetchall()
    except psycopg2.Error as database_error:
        errors.append(f"Database error: {database_error}")

    return render_template(
        "index.html",
        users=users,
        locales=locales,
        locale=locale,
        seed=seed,
        batch=batch,
        batch_size=BATCH_SIZE,
        errors=errors,
    )
