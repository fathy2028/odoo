#!/bin/bash
# Odoo container entrypoint.
#
#  1. Builds $ODOO_RC = config/odoo.conf + database settings from the environment (.env),
#     so credentials are never baked into the image and every odoo-bin command
#     (server, shell, module ...) reads the same configuration.
#  2. Waits for PostgreSQL.
#  3. On a plain start (no arguments), prepares the database $ODOO_DB:
#       - missing database   -> created with $ODOO_INIT_MODULES (+ --with-demo if ODOO_WITH_DEMO=true)
#       - existing database  -> installs whichever of $ODOO_INIT_MODULES are missing,
#                               and loads demo data (module force-demo) if wanted but not loaded yet
#  4. Runs odoo-bin with the given arguments (the web server by default), e.g.:
#       docker compose run --rm odoo shell -d ecom
#       docker compose run --rm odoo module upgrade -d ecom fathy
set -e

: "${DB_HOST:=db}" "${DB_PORT:=5432}" "${DB_USER:=odoo}" "${DB_PASSWORD:=odoo}"
: "${ODOO_DB:=}" "${ODOO_INIT_MODULES:=website_sale,fathy}" "${ODOO_WITH_DEMO:=false}"
: "${ODOO_RC:=/etc/odoo/runtime.conf}"
export DB_HOST DB_PORT DB_USER DB_PASSWORD ODOO_RC
export PGPASSWORD="$DB_PASSWORD"

ODOO_BIN=/opt/odoo/odoo-bin

write_runtime_config() {
    python3 - <<'EOF'
import configparser, os

conf = configparser.ConfigParser(interpolation=None)
conf.read('/etc/odoo/odoo.conf')
options = conf['options']
for key in ('db_host', 'db_port', 'db_user', 'db_password'):
    options[key] = os.environ[key.upper()]

fd = os.open(os.environ['ODOO_RC'], os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, 'w') as f:
    conf.write(f)
EOF
}

wait_for_postgres() {
    for _ in $(seq 1 30); do
        pg_isready -q -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" && return 0
        echo "Waiting for PostgreSQL at $DB_HOST:$DB_PORT..."
        sleep 2
    done
    echo "PostgreSQL is not reachable at $DB_HOST:$DB_PORT" >&2
    exit 1
}

psql_query() {  # psql_query <sql> [database]
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "${2:-postgres}" -tAqc "$1"
}

prepare_database() {
    if [[ ! "$ODOO_DB" =~ ^[A-Za-z0-9_.-]+$ ]]; then
        echo "Invalid ODOO_DB name: '$ODOO_DB'" >&2
        exit 1
    fi

    local with_demo=false
    [[ "${ODOO_WITH_DEMO,,}" =~ ^(true|1|yes)$ ]] && with_demo=true

    local modules=()
    IFS=',' read -ra modules <<< "${ODOO_INIT_MODULES// /}"
    for module in "${modules[@]}"; do
        if [[ ! "$module" =~ ^[a-z0-9_]+$ ]]; then
            echo "Invalid module name in ODOO_INIT_MODULES: '$module'" >&2
            exit 1
        fi
    done

    # New (or empty) database: initialize it in one go
    if [[ "$(psql_query "SELECT 1 FROM pg_database WHERE datname = '$ODOO_DB'")" != "1" ]] \
        || [[ "$(psql_query "SELECT to_regclass('public.ir_module_module') IS NOT NULL" "$ODOO_DB")" != "t" ]]; then
        echo "Creating database '$ODOO_DB' with modules: ${modules[*]} (demo data: $with_demo)"
        local demo_flag=()
        $with_demo && demo_flag=(--with-demo)
        "$ODOO_BIN" -d "$ODOO_DB" -i "$(IFS=,; echo "${modules[*]}")" "${demo_flag[@]}" \
            --stop-after-init --no-http
        return
    fi

    # Existing database: install only what is missing
    local missing=()
    for module in "${modules[@]}"; do
        if [[ "$(psql_query "SELECT state FROM ir_module_module WHERE name = '$module'" "$ODOO_DB")" != "installed" ]]; then
            missing+=("$module")
        fi
    done
    if ((${#missing[@]})); then
        echo "Installing missing modules in '$ODOO_DB': ${missing[*]}"
        "$ODOO_BIN" module install -d "$ODOO_DB" "${missing[@]}"
    fi

    # Demo data wanted but the database was created without it
    if $with_demo && [[ "$(psql_query "SELECT demo FROM ir_module_module WHERE name = 'base'" "$ODOO_DB")" != "t" ]]; then
        echo "Loading demo data into '$ODOO_DB'"
        "$ODOO_BIN" module force-demo -d "$ODOO_DB"
    fi
}

write_runtime_config
wait_for_postgres

# Only prepare the database on a plain start (`docker compose up`), not for one-off commands
if [[ $# -eq 0 && -n "$ODOO_DB" ]]; then
    prepare_database
fi

exec "$ODOO_BIN" "$@"
