#!/bin/bash
set -e

echo "=== Starting Web Server ==="

# Terapkan ACL (iptables) — non-fatal agar server tetap jalan
echo "[*] Applying ACL rules..."
/acl.sh web || echo "[WARN] ACL failed (non-fatal, mungkin butuh NET_ADMIN)"

# Start SNORT di background
echo "[*] Starting SNORT IDS..."
snort -D \
  -i eth0 \
  -c /etc/snort/snort.conf \
  -l /var/log/snort \
  -A fast \
  2>/var/log/snort/snort_startup.log || echo "[WARN] SNORT failed to start (non-fatal)"

echo "[*] Starting Go HTTPS server..."
cd /app && ./server