#!/usr/bin/env bash
set -e

log() {
  echo "[clamav-daemon addon] $*"
}

CONFIG_FILE="/data/options.json"

# Defaults
LISTEN_IP_DEFAULT="0.0.0.0"
LISTEN_PORT_DEFAULT=3310
MAX_FILE_SIZE_MB_DEFAULT=250
STREAM_MAX_LENGTH_MB_DEFAULT=250

log "Starting ClamAV Daemon add-on"

# --------------------------- Read config ----------------------------
if [ -f "$CONFIG_FILE" ]; then
  log "Reading options from ${CONFIG_FILE}"

  LISTEN_IP=$(jq -r '.listen_ip // empty' "$CONFIG_FILE")
  LISTEN_PORT=$(jq -r '.listen_port // empty' "$CONFIG_FILE")
  MAX_FILE_SIZE_MB=$(jq -r '.max_file_size_mb // empty' "$CONFIG_FILE")
  STREAM_MAX_LENGTH_MB=$(jq -r '.stream_max_length_mb // empty' "$CONFIG_FILE")
else
  log "WARNING: ${CONFIG_FILE} not found, using defaults."
fi

LISTEN_IP="${LISTEN_IP:-$LISTEN_IP_DEFAULT}"
LISTEN_PORT="${LISTEN_PORT:-$LISTEN_PORT_DEFAULT}"
MAX_FILE_SIZE_MB="${MAX_FILE_SIZE_MB:-$MAX_FILE_SIZE_MB_DEFAULT}"
STREAM_MAX_LENGTH_MB="${STREAM_MAX_LENGTH_MB:-$STREAM_MAX_LENGTH_MB_DEFAULT}"

log "listen_ip=${LISTEN_IP}, listen_port=${LISTEN_PORT}"
log "MaxFileSize=${MAX_FILE_SIZE_MB}M, StreamMaxLength=${STREAM_MAX_LENGTH_MB}M"

# --------------------------- Prep dirs ------------------------------
mkdir -p /var/lib/clamav /var/log/clamav /run/clamav

# Own everything by the clamav user (UID 100 / GID 101 on Alpine)
if id clamav >/dev/null 2>&1; then
  chown -R clamav:clamav /var/lib/clamav /var/log/clamav /run/clamav
else
  log "WARNING: user 'clamav' not found, leaving ownership as root"
fi

# --------------------------- clamd.conf -----------------------------
log "Writing /etc/clamav/clamd.conf"

cat <<EOF > /etc/clamav/clamd.conf
LogTime yes
LogFile /var/log/clamav/clamd.log
PidFile /run/clamav/clamd.pid
DatabaseDirectory /var/lib/clamav

TCPSocket ${LISTEN_PORT}
TCPAddr ${LISTEN_IP}

User clamav

ScanMail no
ScanArchive yes
StreamMaxLength ${STREAM_MAX_LENGTH_MB}M
MaxFileSize ${MAX_FILE_SIZE_MB}M

Foreground yes
EOF

# --------------------------- freshclam ------------------------------
log "Updating ClamAV database with freshclam (may be rate-limited)..."

if id clamav >/dev/null 2>&1; then
  # run freshclam as clamav user so UID/GID match expectations
  if ! su clamav -s /bin/sh -c "freshclam"; then
    log "WARNING: freshclam failed (possibly rate-limited). Using existing DB if present."
  fi
else
  # fallback: run as root (not ideal, but just in case)
  if ! freshclam; then
    log "WARNING: freshclam failed (possibly rate-limited). Using existing DB if present."
  fi
fi

# If there is still no DB at all, abort with clear error
# If there is still no DB at all, abort with clear error
HAS_CVD=false
HAS_CLD=false

if ls /var/lib/clamav/*.cvd >/dev/null 2>&1; then
  HAS_CVD=true
fi

if ls /var/lib/clamav/*.cld >/dev/null 2>&1; then
  HAS_CLD=true
fi

if [ "$HAS_CVD" = false ] && [ "$HAS_CLD" = false ]; then
  log "ERROR: No ClamAV database files found in /var/lib/clamav after freshclam!"
  log "       clamd cannot start without at least main.cvd. Check network/ DNS and try again."
  exit 1
fi


# --------------------------- start clamd ----------------------------
log "Starting clamd on ${LISTEN_IP}:${LISTEN_PORT}"

if id clamav >/dev/null 2>&1; then
  exec su clamav -s /bin/sh -c "clamd -c /etc/clamav/clamd.conf"
else
  log "WARNING: user 'clamav' not found, starting clamd as root"
  exec clamd -c /etc/clamav/clamd.conf
fi
