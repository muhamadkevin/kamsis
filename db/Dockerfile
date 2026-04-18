FROM mysql:8.0-debian

ENV DEBIAN_FRONTEND=noninteractive

# Init SQL — dijalankan otomatis oleh MySQL image
COPY init.sql /docker-entrypoint-initdb.d/init.sql

EXPOSE 3306
