FROM python:3.13-slim-bookworm

# Pin version for Bitwarden CLI
ARG BW_VERSION="2025.10.0"
ARG BW_NPM_SHA256="b8d8ff6b327733d57ac03158b0f613a64637ab6809b06cb50e6b19eccccbe52f"

# Supercronic variables for multi-arch
ARG SUPERCRONIC_VERSION="v0.2.39"
ARG SUPERCRONIC_SHA1SUM_AMD64="c98bbf82c5f648aaac8708c182cc83046fe48423"
ARG SUPERCRONIC_SHA1SUM_ARM64="d5e02aa760b3d434bc7b991777aa89ef4a503e49"

# Install minimal required packages including Node.js for npm
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    bash \
    unzip \
    ca-certificates \
    gnupg \
    sqlcipher \
    libssl-dev \
    libsqlite3-dev \
    libsqlcipher-dev \
    gcc \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -g 1000 backvault \
 && useradd -m -u 1000 -g 1000 -s /bin/bash backvault

# Install Bitwarden CLI using npm build artifact (works for all architectures)
RUN set -eux; \
    curl -Lo bw-npm.zip "https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bitwarden-cli-${BW_VERSION}-npm-build.zip"; \
    echo "${BW_NPM_SHA256}  bw-npm.zip" | sha256sum -c -; \
    unzip bw-npm.zip -d /tmp/bw-cli; \
    cd /tmp/bw-cli && npm install --production --no-optional; \
    mkdir -p /usr/local/lib/node_modules/@bitwarden; \
    mv /tmp/bw-cli /usr/local/lib/node_modules/@bitwarden/cli; \
    ln -s /usr/local/lib/node_modules/@bitwarden/cli/build/bw.js /usr/local/bin/bw; \
    chmod +x /usr/local/bin/bw; \
    rm -f bw-npm.zip

# Install Supercronic (multi-arch)
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
        amd64) \
            SUPERCRONIC_URL="https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64"; \
            SUPERCRONIC_SHA1SUM="${SUPERCRONIC_SHA1SUM_AMD64}"; \
            SUPERCRONIC="supercronic-linux-amd64"; \
            ;; \
        arm64) \
            SUPERCRONIC_URL="https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-arm64"; \
            SUPERCRONIC_SHA1SUM="${SUPERCRONIC_SHA1SUM_ARM64}"; \
            SUPERCRONIC="supercronic-linux-arm64"; \
            ;; \
        *) \
            echo "Unsupported architecture: ${ARCH}"; \
            exit 1; \
            ;; \
    esac; \
    curl -fsSLO "$SUPERCRONIC_URL"; \
    echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c -; \
    chmod +x "$SUPERCRONIC"; \
    mv "$SUPERCRONIC" /usr/local/bin/supercronic

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

# Clean up build dependencies (keep nodejs for bw cli)
RUN apt-get remove -y curl unzip gnupg gcc && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

ENV PYTHONPATH=/app

USER 1000:1000

ENTRYPOINT ["/app/entrypoint.sh"]
