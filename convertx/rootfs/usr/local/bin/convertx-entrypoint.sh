#!/bin/sh
set -e

OPTIONS_FILE="/data/options.json"

# Defaults (same as in config.yaml so it still works even if options.json is missing)
JWT_SECRET_DEFAULT="1FloareA1"
HTTP_ALLOWED_DEFAULT="true"
TZ_DEFAULT="Europe/Bucharest"
AUTO_DELETE_DEFAULT="720"
CLAMAV_URL_DEFAULT="http://192.168.68.144:3000/api/v1/scan"

JWT_SECRET=""
HTTP_ALLOWED=""
TZ_VAL=""
AUTO_DELETE=""
CLAMAV_URL=""

if [ -f "$OPTIONS_FILE" ] && command -v jq >/dev/null 2>&1; then
  JWT_SECRET="$(jq -r '.jwt_secret // empty' "$OPTIONS_FILE" 2>/dev/null || true)"
  HTTP_ALLOWED="$(jq -r '.http_allowed // empty' "$OPTIONS_FILE" 2>/dev/null || true)"
  TZ_VAL="$(jq -r '.tz // empty' "$OPTIONS_FILE" 2>/dev/null || true)"
  AUTO_DELETE="$(jq -r '.auto_delete_hours // empty' "$OPTIONS_FILE" 2>/dev/null || true)"
  CLAMAV_URL="$(jq -r '.clamav_url // empty' "$OPTIONS_FILE" 2>/dev/null || true)"
fi

[ -z "$JWT_SECRET" ] && JWT_SECRET="$JWT_SECRET_DEFAULT"
[ -z "$HTTP_ALLOWED" ] && HTTP_ALLOWED="$HTTP_ALLOWED_DEFAULT"
[ -z "$TZ_VAL" ] && TZ_VAL="$TZ_DEFAULT"
[ -z "$AUTO_DELETE" ] && AUTO_DELETE="$AUTO_DELETE_DEFAULT"
[ -z "$CLAMAV_URL" ] && CLAMAV_URL="$CLAMAV_URL_DEFAULT"

export JWT_SECRET="$JWT_SECRET"
export HTTP_ALLOWED="$HTTP_ALLOWED"
export TZ="$TZ_VAL"
export AUTO_DELETE_EVERY_N_HOURS="$AUTO_DELETE"
export CLAMAV_URL="$CLAMAV_URL"

# Run the original CMD from the base image with any args HA passes in
exec "$@"
