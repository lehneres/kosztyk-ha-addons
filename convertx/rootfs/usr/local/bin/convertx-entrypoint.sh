#!/bin/sh
set -e

# With map: type: data path: /app/data
# the persistent HA data dir (and options.json) are now under /app/data
OPTIONS_FILE="/app/data/options.json"
DATA_DIR="/app/data"

# Make sure /app/data exists (Supervisor mounts it, but just in case)
mkdir -p "${DATA_DIR}"

# Try to ensure ConvertX can write its DB here
# If chown fails (wrong UID), fall back to chmod 777
chown -R 1000:1000 "${DATA_DIR}" 2>/dev/null || chmod -R 777 "${DATA_DIR}" || true

# Defaults – only used if GUI options are empty
HTTP_ALLOWED_DEFAULT="true"
TZ_DEFAULT="Europe/Bucharest"
AUTO_DELETE_DEFAULT="720"
CLAMAV_URL_DEFAULT="http://172.0.0.1:3000/api/v1/scan"
ACCOUNT_REGISTRATION_DEFAULT="true"
ALLOW_UNAUTHENTICATED_DEFAULT="true"

JWT_SECRET=""
HTTP_ALLOWED=""
TZ_VAL=""
AUTO_DELETE=""
CLAMAV_URL=""
ACCOUNT_REGISTRATION=""
ALLOW_UNAUTHENTICATED=""

# Read options from HA's options.json if present
if [ -f "$OPTIONS_FILE" ] && command -v jq >/dev/null 2>&1; then
  JWT_SECRET="$(jq -r '.jwt_secret // empty' "$OPTIONS_FILE" 2>/dev/null || true)"
  HTTP_ALLOWED="$(jq -r '.http_allowed // empty' "$OPTIONS_FILE" 2>/dev/null || true)"
  TZ_VAL="$(jq -r '.tz // empty' "$OPTIONS_FILE" 2>/dev/null || true)"
  AUTO_DELETE="$(jq -r '.auto_delete_hours // empty' "$OPTIONS_FILE" 2>/dev/null || true)"
  CLAMAV_URL="$(jq -r '.clamav_url // empty' "$OPTIONS_FILE" 2>/dev/null || true)"
  ACCOUNT_REGISTRATION="$(jq -r '.account_registration // empty' "$OPTIONS_FILE" 2>/dev/null || true)"
  ALLOW_UNAUTHENTICATED="$(jq -r '.allow_unauthenticated // empty' "$OPTIONS_FILE" 2>/dev/null || true)"
fi

# Apply defaults if empty
[ -z "$HTTP_ALLOWED" ] && HTTP_ALLOWED="$HTTP_ALLOWED_DEFAULT"
[ -z "$TZ_VAL" ] && TZ_VAL="$TZ_DEFAULT"
[ -z "$AUTO_DELETE" ] && AUTO_DELETE="$AUTO_DELETE_DEFAULT"
[ -z "$CLAMAV_URL" ] && CLAMAV_URL="$CLAMAV_URL_DEFAULT"
[ -z "$ACCOUNT_REGISTRATION" ] && ACCOUNT_REGISTRATION="$ACCOUNT_REGISTRATION_DEFAULT"
[ -z "$ALLOW_UNAUTHENTICATED" ] && ALLOW_UNAUTHENTICATED="$ALLOW_UNAUTHENTICATED_DEFAULT"

# JWT_SECRET can remain empty -> ConvertX will use randomUUID()
# If you want to force it, set it in the GUI.

export JWT_SECRET="$JWT_SECRET"
export HTTP_ALLOWED="$HTTP_ALLOWED"
export TZ="$TZ_VAL"
export AUTO_DELETE_EVERY_N_HOURS="$AUTO_DELETE"
export CLAMAV_URL="$CLAMAV_URL"
export ACCOUNT_REGISTRATION="$ACCOUNT_REGISTRATION"
export ALLOW_UNAUTHENTICATED="$ALLOW_UNAUTHENTICATED"

echo "=== ConvertX add-on env ==="
echo "  HTTP_ALLOWED=$HTTP_ALLOWED"
echo "  ACCOUNT_REGISTRATION=$ACCOUNT_REGISTRATION"
echo "  ALLOW_UNAUTHENTICATED=$ALLOW_UNAUTHENTICATED"
echo "  AUTO_DELETE_EVERY_N_HOURS=$AUTO_DELETE"
echo "  CLAMAV_URL=$CLAMAV_URL"
echo "  TZ=$TZ_VAL"
echo "  JWT_SECRET set? $( [ -n "$JWT_SECRET" ] && echo yes || echo no )"
echo "  DATA_DIR=$DATA_DIR"
ls -ld "$DATA_DIR" || true
echo "==========================="

# Call the original ConvertX entrypoint so behaviour matches plain Docker
if command -v docker-entrypoint.sh >/dev/null 2>&1; then
  exec docker-entrypoint.sh "$@"
elif [ -x /usr/local/bin/docker-entrypoint.sh ]; then
  exec /usr/local/bin/docker-entrypoint.sh "$@"
else
  echo "ERROR: docker-entrypoint.sh not found, cannot start ConvertX" >&2
  exit 1
fi
