FROM golang:1.21-bullseye

ENV DEBIAN_FRONTEND=noninteractive

# =============================================
# Install build deps + runtime tools
# =============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl \
    curl \
    wget \
    iptables \
    procps \
    # Snort build dependencies
    build-essential \
    libpcap-dev \
    libpcre3-dev \
    libdumbnet-dev \
    bison \
    flex \
    zlib1g-dev \
    liblzma-dev \
    libssl-dev \
    pkg-config \
    libluajit-5.1-dev \
    libnghttp2-dev \
    && rm -rf /var/lib/apt/lists/*

# =============================================
# Build DAQ 2.0.7 (required by Snort 2)
# =============================================
ENV DAQ_VERSION=2.0.7
RUN mkdir -p /tmp/snort-build && \
    cd /tmp/snort-build && \
    wget -q https://www.snort.org/downloads/snort/daq-${DAQ_VERSION}.tar.gz && \
    tar -xzf daq-${DAQ_VERSION}.tar.gz && \
    cd daq-${DAQ_VERSION} && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# =============================================
# Build Snort 2.9.20
# =============================================
ENV SNORT_VERSION=2.9.20
RUN cd /tmp/snort-build && \
    wget -q https://www.snort.org/downloads/snort/snort-${SNORT_VERSION}.tar.gz && \
    tar -xzf snort-${SNORT_VERSION}.tar.gz && \
    cd snort-${SNORT_VERSION} && \
    ./configure --enable-sourcefire && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    ln -sf /usr/local/bin/snort /usr/sbin/snort

# Cleanup build files
RUN rm -rf /tmp/snort-build

# =============================================
# Setup Snort directories & config
# =============================================
RUN mkdir -p /etc/snort/rules /var/log/snort /usr/local/lib/snort_dynamicrules

COPY snort/snort.conf /etc/snort/snort.conf
COPY snort/rules/ /etc/snort/rules/

# =============================================
# Generate SSL cert
# =============================================
RUN mkdir -p /app/certs && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /app/certs/key.pem \
    -out /app/certs/cert.pem \
    -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Kamsis/CN=localhost"

# =============================================
# Copy ACL script
# =============================================
COPY acl.sh /acl.sh
RUN chmod +x /acl.sh

# =============================================
# Build Go app
# =============================================
WORKDIR /app
COPY app/go.mod ./
RUN go mod download
COPY app/ .
RUN go mod tidy && go build -o server .

# =============================================
# Copy entrypoint
# =============================================
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 80 443
ENTRYPOINT ["/app/entrypoint.sh"]