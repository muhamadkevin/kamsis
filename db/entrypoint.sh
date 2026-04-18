#!/bin/bash
set -e

echo "=== Starting DB Server ==="

# Terapkan ACL
echo "[*] Applying ACL rules..."
/acl.sh db || echo "[WARN] ACL failed (non-fatal, mungkin butuh NET_ADMIN)"

# Snort tidak diinstall di DB container (tidak tersedia di Bookworm)
# Monitoring network dilakukan oleh Snort di web server
echo "[*] Snort IDS berjalan di web server (monitor semua traffic)"

echo "[*] Starting MySQL..."
exec docker-entrypoint.sh mysqld