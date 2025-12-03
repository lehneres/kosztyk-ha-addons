#!/bin/sh
set -e

echo "[INFO] Pulse PVE Monitoring add-on starting"

# Ensure data dir exists
if [ ! -d "/data" ]; then
  mkdir -p /data
fi

# Log level env (optional)
if [ -n "$LOG_LEVEL" ]; then
  echo "[INFO] LOG_LEVEL=$LOG_LEVEL"
fi

# Start Pulse (binary from the base image)
# The Docker Hub layer listing shows the Pulse binary is installed and used there.
# Just call it directly; no bash involved.
if command -v pulse >/dev/null 2>&1; then
  echo "[INFO] Starting Pulse via 'pulse' binary..."
  exec pulse
else
  echo "[ERROR] 'pulse' binary not found in container PATH"
  ls -R /
  sleep 300
fi
