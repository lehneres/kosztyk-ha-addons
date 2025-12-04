FROM benzino77/clamav-rest-api:latest

COPY run.sh /run.sh
RUN chmod a+x /run.sh

WORKDIR /opt/app
EXPOSE 3000

CMD ["/run.sh"]
