FROM debian:trixie

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      postgresql-client \
      awscli \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY backup.sh /usr/local/bin/backup.sh
COPY restore.sh /usr/local/bin/restore.sh
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/restore.sh

ENTRYPOINT ["backup.sh"]
