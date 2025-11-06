FROM alpine:latest

# Install required system packages
RUN apk add --no-cache \
    curl \
    unzip \
    bash \
    dcron \
    && rm -rf /var/cache/apk/*

# Install Bitwarden CLI
RUN set -eux; \
    curl -Lo bw.zip "https://bitwarden.com/download/?app=cli&platform=linux"; \
    unzip bw.zip -d /usr/local/bin; \
    chmod +x /usr/local/bin/bw; \
    rm bw.zip

# Create a script to run the backup and cleanup old backups
RUN printf '%s\n' '#!/bin/bash' \
    'set -eux' \
    '/usr/local/bin/bw export --output /app/backups/backup_$(date +\%Y\%m\%d_\%H\%M\%S).json --format json --password ${PASSWORD}' \
    'find /app/backups -name "backup_*.json" -type f -mtime +7 -delete' \
    > /app/backup.sh && \
    chmod +x /app/backup.sh

# Copy application files
COPY . /app
WORKDIR /app

# Set up cron job
RUN echo "0 */12 * * * /bin/bash /app/backup.sh >> /var/log/cron.log 2>&1" | crontab -

# Start cron in the foreground
CMD ["crond", "-f"]
