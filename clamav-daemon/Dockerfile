ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

# Run as root so we can read /data/options.json and manage ClamAV dirs
USER root

# Install ClamAV daemon + bash + jq (for reading /data/options.json)
RUN apk add --no-cache clamav-daemon bash jq

# Copy startup script
COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

WORKDIR /tmp

EXPOSE 3310

CMD ["/usr/local/bin/run.sh"]
