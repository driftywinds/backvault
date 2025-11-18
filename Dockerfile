FROM python:3.13-alpine

ARG BW_VERSION="2025.10.0"
ARG ARCHITECTURE="${ARCH:-amd64}"
ARG SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.39/supercronic-linux-amd64
ARG SUPERCRONIC_SHA1SUM=c98bbf82c5f648aaac8708c182cc83046fe48423
ARG SUPERCRONIC=supercronic-linux-amd64
ARG SUPERCRONIC_URL_ARM=https://github.com/aptible/supercronic/releases/download/v0.2.39/supercronic-linux-arm64
ARG SUPERCRONIC_SHA1SUM_ARM=5ef4ccc3d43f12d0f6c3763758bc37cc4e5af76e
ARG SUPERCRONIC_ARM=supercronic-linux-arm64

# Install minimal required packages
RUN apk update && apk add --no-cache \
    curl \
    bash \
    unzip \
    sqlcipher \
    libressl-dev \
    sqlite-dev \
    sqlcipher-dev \
    build-base \
    python3-dev \
    gcompat \
    nodejs \
    npm \
    && rm -rf /var/lib/apk/*

RUN apk upgrade -a

# Install Bitwarden CLI
RUN set -eux; \
    echo "Installing Bitwarden CLI version: ${BW_VERSION} with Node.js $(node --version)"; \
    npm install -g @bitwarden/cli@${BW_VERSION}; \
    bw --version

RUN set -eux; \
    case "${ARCHITECTURE}" in \
        arm) \
            SUPERCRONIC_URL=${SUPERCRONIC_URL_ARM}; \
            SUPERCRONIC_SHA1SUM=${SUPERCRONIC_SHA1SUM_ARM}; \
            SUPERCRONIC=${SUPERCRONIC_ARM} \
            ;; \
        amd64) \
            SUPERCRONIC_URL=${SUPERCRONIC_URL}; \
            SUPERCRONIC_SHA1SUM=${SUPERCRONIC_SHA1SUM}; \
            SUPERCRONIC=${SUPERCRONIC} \
            ;; \
        *) \
            echo "Unsupported architecture: ${ARCHITECTURE}" >&2; \
            exit 1 \
            ;; \
    esac; \
    \
    curl -fsSLO "$SUPERCRONIC_URL" \
    && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
    && chmod +x "$SUPERCRONIC" \
    && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
    && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

# Prepare working directories
RUN mkdir -p /app/logs /app/backups /app/db /app/src && \
    chmod -R 700 /app && \
    chown -R 1000:1000 /app

# Copy project files
WORKDIR /app

COPY --chown=1000:1000 ./requirements.txt /app/requirements.txt
COPY --chown=1000:1000 ./src /app/src
COPY --chown=1000:1000 ./entrypoint.sh /app/entrypoint.sh
COPY --chown=1000:1000 ./cleanup.sh /app/cleanup.sh

RUN chmod +x /app/entrypoint.sh /app/cleanup.sh

# Install Python dependencies
RUN pip install --upgrade pip && \
    pip install --no-input --no-cache-dir -r requirements.txt

RUN apk del curl unzip binutils nodejs npm --no-cache

ENV PYTHONPATH=/app

USER 1000:1000

ENTRYPOINT ["/app/entrypoint.sh"]
