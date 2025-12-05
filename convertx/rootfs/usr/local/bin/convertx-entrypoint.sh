#!/bin/sh
set -e

# ConvertX database is hardcoded to "./data/mydb.sqlite" (relative to /app)
# So we need: /app/data/mydb.sqlite -> /data/convertx/mydb.sqlite
PERSISTENT_DIR="/data/convertx"
DB_FILE="${PERSISTENT_DIR}/mydb.sqlite"
OPTIONS_FILE="/data/options.json"

echo "=========================================="
echo "ConvertX Add-on"
echo "Database path: ${DB_FILE}"
echo "=========================================="
echo ""

# Create persistent directory
mkdir -p "${PERSISTENT_DIR}"
chmod 777 "${PERSISTENT_DIR}" 2>/dev/null || true

# Backup any existing /app/data if it's not already a symlink
if [ -d "/app/data" ] && [ ! -L "/app/data" ]; then
    echo "Backing up existing /app/data..."
    cp -r /app/data/* "${PERSISTENT_DIR}/" 2>/dev/null || true
    mv /app/data /app/data.backup
fi

# Create symlink
ln -sf "${PERSISTENT_DIR}" /app/data 2>/dev/null || echo "Note: Could not create symlink"

# Ensure database file exists and is writable
touch "${DB_FILE}"
chmod 666 "${DB_FILE}" 2>/dev/null || true

echo "Persistent data directory: ${PERSISTENT_DIR}"
echo "Symlink: /app/data -> ${PERSISTENT_DIR}"
echo "Database: ${DB_FILE}"
ls -la "${DB_FILE}" 2>/dev/null || echo "Cannot check database file"
echo ""

# Read configuration
if [ -f "${OPTIONS_FILE}" ] && command -v jq >/dev/null 2>&1; then
    echo "Reading configuration from ${OPTIONS_FILE}"
    
    JWT_SECRET=$(jq -r '.jwt_secret // empty' "${OPTIONS_FILE}" 2>/dev/null || echo "")
    ACCOUNT_REGISTRATION=$(jq -r '.account_registration // "true"' "${OPTIONS_FILE}" 2>/dev/null || echo "true")
    HTTP_ALLOWED=$(jq -r '.http_allowed // "false"' "${OPTIONS_FILE}" 2>/dev/null || echo "false")
    ALLOW_UNAUTHENTICATED=$(jq -r '.allow_unauthenticated // "false"' "${OPTIONS_FILE}" 2>/dev/null || echo "false")
    AUTO_DELETE_EVERY_N_HOURS=$(jq -r '.auto_delete_hours // "24"' "${OPTIONS_FILE}" 2>/dev/null || echo "24")
    WEBROOT=$(jq -r '.webroot // empty' "${OPTIONS_FILE}" 2>/dev/null || echo "")
    FFMPEG_ARGS=$(jq -r '.ffmpeg_args // empty' "${OPTIONS_FILE}" 2>/dev/null || echo "")
    HIDE_HISTORY=$(jq -r '.hide_history // "false"' "${OPTIONS_FILE}" 2>/dev/null || echo "false")
    LANGUAGE=$(jq -r '.language // "en"' "${OPTIONS_FILE}" 2>/dev/null || echo "en")
    UNAUTHENTICATED_USER_SHARING=$(jq -r '.unauthenticated_user_sharing // "false"' "${OPTIONS_FILE}" 2>/dev/null || echo "false")
    MAX_CONVERT_PROCESS=$(jq -r '.max_convert_process // "0"' "${OPTIONS_FILE}" 2>/dev/null || echo "0")
    CLAMAV_URL=$(jq -r '.clamav_url // "http://172.0.0.1:3000/api/v1/scan"' "${OPTIONS_FILE}" 2>/dev/null || echo "http://172.0.0.1:3000/api/v1/scan")
    TZ_VAL=$(jq -r '.tz // "Europe/Bucharest"' "${OPTIONS_FILE}" 2>/dev/null || echo "Europe/Bucharest")
    NODE_ENV_VAL=$(jq -r '.NODE_ENV // "production"' "${OPTIONS_FILE}" 2>/dev/null || echo "production")
else
    echo "Using default configuration"
    JWT_SECRET=""
    ACCOUNT_REGISTRATION="true"
    HTTP_ALLOWED="false"
    ALLOW_UNAUTHENTICATED="false"
    AUTO_DELETE_EVERY_N_HOURS="24"
    WEBROOT=""
    FFMPEG_ARGS=""
    HIDE_HISTORY="false"
    LANGUAGE="en"
    UNAUTHENTICATED_USER_SHARING="false"
    MAX_CONVERT_PROCESS="0"
    CLAMAV_URL="http://172.0.0.1:3000/api/v1/scan"
    TZ_VAL="Europe/Bucharest"
    NODE_ENV_VAL="production"
fi

# Export environment variables
export JWT_SECRET="${JWT_SECRET}"
export ACCOUNT_REGISTRATION="${ACCOUNT_REGISTRATION}"
export HTTP_ALLOWED="${HTTP_ALLOWED}"
export ALLOW_UNAUTHENTICATED="${ALLOW_UNAUTHENTICATED}"
export AUTO_DELETE_EVERY_N_HOURS="${AUTO_DELETE_EVERY_N_HOURS}"
export WEBROOT="${WEBROOT}"
export FFMPEG_ARGS="${FFMPEG_ARGS}"
export HIDE_HISTORY="${HIDE_HISTORY}"
export LANGUAGE="${LANGUAGE}"
export UNAUTHENTICATED_USER_SHARING="${UNAUTHENTICATED_USER_SHARING}"
export MAX_CONVERT_PROCESS="${MAX_CONVERT_PROCESS}"
export CLAMAV_URL="${CLAMAV_URL}"
export TZ="${TZ_VAL}"
export NODE_ENV="${NODE_ENV_VAL}"

echo "=========================================="
echo "Configuration:"
echo "ACCOUNT_REGISTRATION: ${ACCOUNT_REGISTRATION}"
echo "ALLOW_UNAUTHENTICATED: ${ALLOW_UNAUTHENTICATED}"
echo "Database: ${DB_FILE}"
echo "=========================================="
echo ""

# Check database
if command -v sqlite3 >/dev/null 2>&1; then
    echo "Checking database..."
    if sqlite3 "${DB_FILE}" "SELECT 1;" 2>/dev/null; then
        TABLES=$(sqlite3 "${DB_FILE}" ".tables" 2>/dev/null)
        if [ -n "${TABLES}" ]; then
            echo "Database has tables: ${TABLES}"
            
            # Check for users
            if echo "${TABLES}" | grep -q "users"; then
                USER_COUNT=$(sqlite3 "${DB_FILE}" "SELECT COUNT(*) FROM users;" 2>/dev/null || echo "0")
                echo "User accounts: ${USER_COUNT}"
                
                if [ "${ACCOUNT_REGISTRATION}" = "false" ] && [ "${USER_COUNT}" = "0" ]; then
                    echo ""
                    echo "❌ ERROR: No users in database but registration is disabled!"
                    echo "   Set 'account_registration: true' in add-on options"
                    echo ""
                fi
            fi
        else
            echo "Database is empty (first run)"
        fi
    fi
fi

echo "Starting ConvertX..."
echo "=========================================="

# Start ConvertX (uses Bun based on earlier output)
cd /app
if command -v bun >/dev/null 2>&1; then
    exec bun run dist/src/index.js
else
    exec node dist/src/index.js
fi
