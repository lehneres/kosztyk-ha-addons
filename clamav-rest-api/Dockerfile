ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
# For multi-arch, HA will override BUILD_FROM automatically.
FROM ${BUILD_FROM}

# Install bash & curl if not present
RUN apk add --no-cache bash curl

# Copy run script
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# Pull the original image’s filesystem into /opt/app
# We'll run it via Docker-in-Docker style (multi-stage is cleaner but HA
# add-ons generally don't use multi-stage from external images directly),
# so instead we will just run the original image as our base:

# NOTE: simpler: just re-use upstream image as base directly instead:
# FROM benzino77/clamav-rest-api:latest
# but then BUILD_FROM is not used. If that's fine for you, comment the above
# and use the simpler variant:

# ---- SIMPLE VARIANT (RECOMMENDED) ----
# FROM benzino77/clamav-rest-api:latest
# COPY run.sh /run.sh
# RUN chmod a+x /run.sh
# -------------------------------------

# Set working dir same as upstream (according to the image docs)
WORKDIR /opt/app

EXPOSE 3000

CMD ["/run.sh"]
