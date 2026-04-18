FROM golang:1.21-bullseye AS builder

WORKDIR /app
COPY app/go.mod ./
RUN go mod download
COPY app/ .
RUN go mod tidy && CGO_ENABLED=0 go build -o server .

# =============================================
# Runtime stage: Debian Buster (has Snort in repos)
# =============================================
FROM debian:buster-slim

ENV DEBIAN_FRONTEND=noninteractive

# Use archive repos (Buster is EOL)
RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list

# Install Snort, iptables, openssl, and tools
RUN apt-get update -o Acquire::Check-Valid-Until=false && \
    apt-get install -y --no-install-recommends \
    snort \
    iptables \
    openssl \
    curl \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Generate SSL cert
RUN mkdir -p /app/certs && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /app/certs/key.pem \
    -out /app/certs/cert.pem \
    -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Kamsis/CN=localhost"

# Setup Snort config & rules
RUN mkdir -p /etc/snort/rules /var/log/snort
COPY snort/snort.conf /etc/snort/snort.conf
COPY snort/rules/ /etc/snort/rules/

# Fix CRLF line endings (files dari Windows)
RUN sed -i 's/\r$//' /etc/snort/snort.conf && \
    find /etc/snort/rules -type f -exec sed -i 's/\r$//' {} \;

# Copy ACL script
COPY acl.sh /acl.sh
RUN chmod +x /acl.sh

# Copy Go binary from builder
WORKDIR /app
COPY --from=builder /app/server ./server

# Copy templates
COPY app/templates/ ./templates/

# Copy entrypoint
COPY entrypoint.sh /app/entrypoint.sh
RUN sed -i 's/\r$//' /app/entrypoint.sh /acl.sh && chmod +x /app/entrypoint.sh /acl.sh

EXPOSE 80 443
ENTRYPOINT ["/app/entrypoint.sh"]