#!/bin/sh
set -e

# Home Assistant add-on data directory - using your preferred location
ADDON_DATA_DIR="/addons/convertx"
DATA_DIR="${ADDON_DATA_DIR}/data"
DB_DIR="${DATA_DIR}/db"
OPTIONS_FILE="${DATA_DIR}/options.json"

# Ensure all directories exist
mkdir -p "${ADDON_DATA_DIR}" "${DATA_DIR}" "${DB_DIR}"

# CRITICAL: Set proper permissions for SQLite database
# Home Assistant typically runs containers as root, but the app runs as node user
echo "Setting permissions for data directories..."

# First, check current ownership
echo "Current ownership of ${ADDON_DATA_DIR}:"
ls -ld "${ADDON_DATA_DIR}" 2>/dev/null || echo "Cannot list ${ADDON_DATA_DIR}"

# Try to set ownership to node user (UID 1000)
# This is what the Node.js application expects
chown -R 1000:1000 "${ADDON_DATA_DIR}" 2>/dev/null && echo "Changed ownership to 1000:1000" || echo "Ownership change failed, using permissions instead"

# Ensure write permissions - this is critical for SQLite
chmod -R 755 "${DATA_DIR}" 2>/dev/null || true
chmod -R 777 "${DB_DIR}" 2>/dev/null || true
chmod 777 "${DATA_DIR}" 2>/dev/null || true

# Default values
JWT_SECRET_DEFAULT=""
ACCOUNT_REGISTRATION_DEFAULT="true"  # Enable for first run
HTTP_ALLOWED_DEFAULT="true"          # Allow HTTP in local network
ALLOW_UNAUTHENTICATED_DEFAULT="false"
AUTO_DELETE_EVERY_N_HOURS_DEFAULT="24"
TZ_DEFAULT="Europe/Bucharest"
CLAMAV_URL_DEFAULT=""
DATABASE_URL_DEFAULT="file:${DB_DIR}/convertx.db"

# Read configuration from Home Assistant options.json
if [ -f "${OPTIONS_FILE}" ] && command -v jq >/dev/null 2>&1; then
    echo "Reading configuration from ${OPTIONS_FILE}"
    JWT_SECRET=$(jq -r '.jwt_secret // empty' "${OPTIONS_FILE}")
    ACCOUNT_REGISTRATION=$(jq -r '.account_registration // "'"${ACCOUNT_REGISTRATION_DEFAULT}"'"' "${OPTIONS_FILE}")
    HTTP_ALLOWED=$(jq -r '.http_allowed // "'"${HTTP_ALLOWED_DEFAULT}"'"' "${OPTIONS_FILE}")
    ALLOW_UNAUTHENTICATED=$(jq -r '.allow_unauthenticated // "'"${ALLOW_UNAUTHENTICATED_DEFAULT}"'"' "${OPTIONS_FILE}")
    AUTO_DELETE_EVERY_N_HOURS=$(jq -r '.auto_delete_hours // "'"${AUTO_DELETE_EVERY_N_HOURS_DEFAULT}"'"' "${OPTIONS_FILE}")
    CLAMAV_URL=$(jq -r '.clamav_url // empty' "${OPTIONS_FILE}")
    TZ_VAL=$(jq -r '.tz // "'"${TZ_DEFAULT}"'"' "${OPTIONS_FILE}")
else
    echo "No options.json found, using defaults"
    # Use defaults
    JWT_SECRET="${JWT_SECRET_DEFAULT}"
    ACCOUNT_REGISTRATION="${ACCOUNT_REGISTRATION_DEFAULT}"
    HTTP_ALLOWED="${HTTP_ALLOWED_DEFAULT}"
    ALLOW_UNAUTHENTICATED="${ALLOW_UNAUTHENTICATED_DEFAULT}"
    AUTO_DELETE_EVERY_N_HOURS="${AUTO_DELETE_EVERY_N_HOURS_DEFAULT}"
    CLAMAV_URL="${CLAMAV_URL_DEFAULT}"
    TZ_VAL="${TZ_DEFAULT}"
fi

# Export all environment variables ConvertX needs
export JWT_SECRET="${JWT_SECRET}"
export ACCOUNT_REGISTRATION="${ACCOUNT_REGISTRATION}"
export HTTP_ALLOWED="${HTTP_ALLOWED}"
export ALLOW_UNAUTHENTICATED="${ALLOW_UNAUTHENTICATED}"
export AUTO_DELETE_EVERY_N_HOURS="${AUTO_DELETE_EVERY_N_HOURS}"
export CLAMAV_URL="${CLAMAV_URL}"
export TZ="${TZ_VAL}"
export NODE_ENV="production"

# Export database location
export DATABASE_URL="${DATABASE_URL_DEFAULT}"

# Create symbolic links so ConvertX can find its data
echo "Setting up symbolic links..."
if [ -d "/app/data" ] && [ ! -L "/app/data" ]; then
    echo "Backing up existing /app/data to /app/data.bak"
    mv "/app/data" "/app/data.bak"
fi

# Link the entire data directory
ln -sf "${DATA_DIR}" "/app/data" 2>/dev/null || echo "Could not create symlink, continuing..."

# Link specifically to database directory
ln -sf "${DB_DIR}" "/app/db" 2>/dev/null || echo "Could not create db symlink"

# Handle the database file
DB_FILE="${DB_DIR}/convertx.db"
echo "Database location: ${DB_FILE}"

# Ensure database file exists and has correct permissions
touch "${DB_FILE}"
chmod 666 "${DB_FILE}" 2>/dev/null || echo "Warning: Could not set permissions on ${DB_FILE}"
chown 1000:1000 "${DB_FILE}" 2>/dev/null || echo "Warning: Could not change ownership of ${DB_FILE}"

echo ""
echo "=========================================="
echo "ConvertX Configuration Summary"
echo "=========================================="
echo "Add-on Data Directory: ${ADDON_DATA_DIR}"
echo "Data Directory: ${DATA_DIR}"
echo "Database Directory: ${DB_DIR}"
echo "Database File: ${DB_FILE}"
echo ""
echo "Application Settings:"
echo "  ACCOUNT_REGISTRATION: ${ACCOUNT_REGISTRATION}"
echo "  HTTP_ALLOWED: ${HTTP_ALLOWED}"
echo "  ALLOW_UNAUTHENTICATED: ${ALLOW_UNAUTHENTICATED}"
echo "  AUTO_DELETE_EVERY_N_HOURS: ${AUTO_DELETE_EVERY_N_HOURS}"
echo "  TIMEZONE: ${TZ_VAL}"
echo "  CLAMAV_URL: ${CLAMAV_URL:-'Not set'}"
echo "  JWT_SECRET: $(if [ -n "${JWT_SECRET}" ]; then echo "Custom value set"; else echo "Using randomUUID()"; fi)"
echo ""
echo "Permissions Check:"
echo "  Data dir exists: $(if [ -d "${DATA_DIR}" ]; then echo "Yes"; else echo "No"; fi)"
echo "  DB dir exists: $(if [ -d "${DB_DIR}" ]; then echo "Yes"; else echo "No"; fi)"
echo "  DB file exists: $(if [ -f "${DB_FILE}" ]; then echo "Yes"; else echo "No"; fi)"
echo "  DB file permissions: $(ls -la "${DB_FILE}" 2>/dev/null | awk '{print $1}' || echo "Cannot check")"
echo "=========================================="
echo ""

# Check directory contents
echo "Contents of ${DATA_DIR}:"
ls -la "${DATA_DIR}/" 2>/dev/null || echo "Cannot list directory"

# Important warning about authentication
if [ "${ACCOUNT_REGISTRATION}" = "false" ]; then
    echo ""
    echo "⚠️  IMPORTANT: Account registration is DISABLED!"
    echo "   If this is your first time running ConvertX, you WON'T be able to login."
    echo "   To fix this:"
    echo "   1. Stop this add-on"
    echo "   2. Edit add-on configuration"
    echo "   3. Set 'account_registration' to true"
    echo "   4. Save and start the add-on"
    echo "   5. Create your account at http://[YOUR-HA-IP]:8080"
    echo "   6. Then disable registration for security"
    echo ""
fi

# Check if we need to initialize the database
if [ ! -s "${DB_FILE}" ]; then
    echo "Database file is empty or doesn't exist. ConvertX will initialize it on first run."
    echo "If you have an existing database, copy it to: ${DB_FILE}"
    echo "Then set permissions: chmod 666 ${DB_FILE}"
fi

echo "Starting ConvertX application..."
echo "=========================================="

# Switch to node user and start the application
# Using gosu or su-exec is better than su for Docker
if command -v su-exec >/dev/null 2>&1; then
    echo "Using su-exec to switch to node user"
    exec su-exec node:node npm start
elif command -v gosu >/dev/null 2>&1; then
    echo "Using gosu to switch to node user"
    exec gosu node npm start
else
    echo "Using su to switch to node user"
    exec su node -c "npm start"
fi
