ARG BUILD_FROM
FROM ${BUILD_FROM}

# Always run as root in the add-on
USER root

# Install ClamAV daemon (includes freshclam, configs in /etc/clamav)
RUN apk add --no-cache clamav-daemon

# Our startup script
COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

WORKDIR /tmp

EXPOSE 3310

CMD ["/usr/local/bin/run.sh"]
