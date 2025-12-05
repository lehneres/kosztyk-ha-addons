ARG BUILD_FROM=kosztyk/convertx-clamav:user
FROM ${BUILD_FROM}

USER root

# Install jq and sqlite3 for our script
RUN if command -v apk >/dev/null 2>&1; then \
      apk add --no-cache jq sqlite; \
    elif command -v apt-get >/dev/null 2>&1; then \
      apt-get update && apt-get install -y jq sqlite3 && rm -rf /var/lib/apt/lists/*; \
    fi

# Create persistent directory
RUN mkdir -p /data/convertx

# Our entrypoint wrapper
COPY rootfs/ /

RUN chmod +x /usr/local/bin/convertx-entrypoint.sh

# Use our entrypoint
ENTRYPOINT ["/usr/local/bin/convertx-entrypoint.sh"]
