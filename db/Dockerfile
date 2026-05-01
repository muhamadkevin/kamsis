FROM mysql:8.0-debian

ENV DEBIAN_FRONTEND=noninteractive

# Install iptables for ACL
RUN apt-get update && apt-get install -y --no-install-recommends iptables procps && rm -rf /var/lib/apt/lists/*

# Copy ACL and entrypoint
COPY acl.sh /acl.sh
COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh /acl.sh && chmod +x /entrypoint.sh /acl.sh

# Init SQL — dijalankan otomatis oleh MySQL image
COPY init.sql /docker-entrypoint-initdb.d/init.sql

EXPOSE 3306

ENTRYPOINT ["/entrypoint.sh"]
