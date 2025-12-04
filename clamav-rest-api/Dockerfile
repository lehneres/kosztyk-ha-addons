FROM benzino77/clamav-rest-api:latest

# Switch to root so we can install tools
USER root

# We need bash & jq to read /data/options.json from HA
RUN apk add --no-cache bash jq

# Copy our wrapper script to a safe path
COPY run.sh /usr/local/bin/clamav-addon-run.sh

# Back to the original non-root user of the base image
USER node

# Upstream app lives here
WORKDIR /clamav-rest-api

EXPOSE 3000

# Run our wrapper via bash (no need for chmod on the script)
CMD ["bash", "/usr/local/bin/clamav-addon-run.sh"]
