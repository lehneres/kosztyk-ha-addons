#!/bin/sh
set -e

OPTIONS_FILE="/app/data/options.json"
DATA_DIR="/app/data"
CONFIG_DIR="/app/data/config"

# Ensure directories exist
mkdir -p "${DATA_DIR}" "${CONFIG_DIR}"

# Set permissions (fallback to 777 if chown fails)
chown -R 1000:1000 "${DATA_DIR}" 2>/dev/null || chmod -R 777 "${DATA_DIR}" 2>/dev/null || true

# Default values
HTTP_ALLOWED_DEFAULT="true"
TZ_DEFAULT="Europe/Bucharest"
AUTO_DELETE_DEFAULT="720"
CLAMAV_URL_DEFAULT="http://172.0.0.1:3000/api/v1/scan"
ACCOUNT_REGISTRATION_DEFAULT="true"
ALLOW_UNAUTHENTICATED_DEFAULT="true"
PORT_DEFAULT="3000"

# Read Home Assistant options
if [ -f "$OPTIONS_FILE" ] && command -v jq >/dev/null 2>&1; then
  JWT_SECRET=$(jq -r '.jwt_secret // empty' "$OPTIONS_FILE" 2>/dev/null || echo "")
  HTTP_ALLOWED=$(jq -r '.http_allowed // empty' "$OPTIONS_FILE" 2>/dev/null || echo "$HTTP_ALLOWED_DEFAULT")
  TZ_VAL=$(jq -r '.tz // empty' "$OPTIONS_FILE" 2>/dev/null || echo "$TZ_DEFAULT")
  AUTO_DELETE=$(jq -r '.auto_delete_hours // empty' "$OPTIONS_FILE" 2>/dev/null || echo "$AUTO_DELETE_DEFAULT")
  CLAMAV_URL=$(jq -r '.clamav_url // empty' "$OPTIONS_FILE" 2>/dev/null || echo "$CLAMAV_URL_DEFAULT")
  ACCOUNT_REGISTRATION=$(jq -r '.account_registration // empty' "$OPTIONS_FILE" 2>/dev/null || echo "$ACCOUNT_REGISTRATION_DEFAULT")
  ALLOW_UNAUTHENTICATED=$(jq -r '.allow_unauthenticated // empty' "$OPTIONS_FILE" 2>/dev/null || echo "$ALLOW_UNAUTHENTICATED_DEFAULT")
else
  # Use defaults if options.json doesn't exist
  JWT_SECRET=""
  HTTP_ALLOWED="$HTTP_ALLOWED_DEFAULT"
  TZ_VAL="$TZ_DEFAULT"
  AUTO_DELETE="$AUTO_DELETE_DEFAULT"
  CLAMAV_URL="$CLAMAV_URL_DEFAULT"
  ACCOUNT_REGISTRATION="$ACCOUNT_REGISTRATION_DEFAULT"
  ALLOW_UNAUTHENTICATED="$ALLOW_UNAUTHENTICATED_DEFAULT"
fi

# Export environment variables
# Note: ConvertX might use different variable names - check the source code
export JWT_SECRET="$JWT_SECRET"
export NODE_ENV="production"
export PORT="$PORT_DEFAULT"
export TZ="$TZ_VAL"

# These are specific to ConvertX's configuration
export CONVERTX_HTTP_ALLOWED="$HTTP_ALLOWED"
export CONVERTX_AUTO_DELETE_HOURS="$AUTO_DELETE"
export CONVERTX_CLAMAV_URL="$CLAMAV_URL"
export CONVERTX_ACCOUNT_REGISTRATION="$ACCOUNT_REGISTRATION"
export CONVERTX_ALLOW_UNAUTHENTICATED="$ALLOW_UNAUTHENTICATED"

# Also set as generic variables (some apps check both)
export HTTP_ALLOWED="$HTTP_ALLOWED"
export AUTO_DELETE_EVERY_N_HOURS="$AUTO_DELETE"
export CLAMAV_URL="$CLAMAV_URL"
export ACCOUNT_REGISTRATION="$ACCOUNT_REGISTRATION"
export ALLOW_UNAUTHENTICATED="$ALLOW_UNAUTHENTICATED"

echo "=== ConvertX Add-on Configuration ==="
echo "Data Directory: $DATA_DIR"
echo "Config Directory: $CONFIG_DIR"
echo "HTTP Allowed: $HTTP_ALLOWED"
echo "Account Registration: $ACCOUNT_REGISTRATION"
echo "Allow Unauthenticated: $ALLOW_UNAUTHENTICATED"
echo "Auto Delete Hours: $AUTO_DELETE"
echo "ClamAV URL: $CLAMAV_URL"
echo "Timezone: $TZ_VAL"
echo "JWT Secret set: $( [ -n "$JWT_SECRET" ] && echo "Yes" || echo "No - using random" )"
echo "======================================"

# Check if this is the first run
FIRST_RUN_FILE="$DATA_DIR/.first-run"
if [ ! -f "$FIRST_RUN_FILE" ]; then
  echo "First run detected - initializing ConvertX..."
  touch "$FIRST_RUN_FILE"
  
  # If you're having authentication issues, you might need to:
  # 1. Check ConvertX's default credentials
  # 2. Or enable account registration initially
  echo "Tip: If you can't login, try:"
  echo "1. Enable 'account_registration' in add-on options"
  echo "2. Create an account via the web UI"
  echo "3. Then disable registration if desired"
fi

# Call the original entrypoint
if command -v docker-entrypoint.sh >/dev/null 2>&1; then
  exec docker-entrypoint.sh "$@"
elif [ -x /usr/local/bin/docker-entrypoint.sh ]; then
  exec /usr/local/bin/docker-entrypoint.sh "$@"
elif [ -f /app/docker-entrypoint.sh ]; then
  exec /app/docker-entrypoint.sh "$@"
else
  echo "WARNING: Could not find original entrypoint, starting directly..."
  # Try to start the application directly
  if [ -f /app/package.json ]; then
    cd /app && exec npm start
  else
    echo "ERROR: Cannot start ConvertX - no entrypoint found" >&2
    exit 1
  fi
fi
