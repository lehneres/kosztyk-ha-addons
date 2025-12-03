#!/usr/bin/with-contenv bashio
# shellcheck shell=bash

set -e

bashio::log.info "Starting Tesseract OCR API add-on"

cd /app

# Optional health check log
bashio::log.info "Running uvicorn on 0.0.0.0:8000"
/usr/bin/python -m uvicorn app:app --host 0.0.0.0 --port 8000
