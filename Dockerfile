FROM ruby:2.7-slim

ARG CH_VERSION=25.5.3.75
ARG PG_VERSION=14

RUN apt-get update && \
    apt-get install -y \
        wget htop lbzip2 gnupg2 build-essential \
        libxml2-dev libxslt-dev liblzma-dev zlib1g-dev \
        patch libpq5 cron locales tzdata && \
    echo "deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg arch=$(dpkg --print-architecture)] https://packages.clickhouse.com/deb stable main" > /etc/apt/sources.list.d/clickhouse.list && \
    wget --quiet -O - 'https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key' | gpg --dearmor -o /usr/share/keyrings/clickhouse-keyring.gpg && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update && \
    apt-get install -y \
        postgresql-client-$PG_VERSION \
        mariadb-client \
        clickhouse-client=$CH_VERSION \
        clickhouse-common-static=$CH_VERSION && \
    rm -rf /var/lib/apt/lists/* /var/cache/debconf && \
    apt-get clean

# Create workdir
RUN mkdir /backup
WORKDIR /backup

# Prepare ruby & gems
COPY Gemfile /backup/Gemfile
COPY Gemfile.lock /backup/Gemfile.lock
RUN gem install bundler -v 2.2.15 && bundle install

# Copy scripts
COPY scripts/ /backup/
RUN chmod 0700 -R /backup/

# Define default CRON_SCHEDULE to 1 your
ENV BACKUP_CRON_SCHEDULE="0 * * * *"
ENV BACKUP_PRIORITY="ionice -c 3 nice -n 10"

# Prepare cron
RUN touch /etc/logrotate.d/rsyslog
ADD crontab /etc/cron.d/backup-cron
RUN chmod 0644 /etc/cron.d/backup-cron

# Run the command on container startup
ENTRYPOINT /backup/run_cron.sh
