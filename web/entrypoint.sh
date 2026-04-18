#!/bin/bash
set -e

echo "=== Starting Web Server ==="

# Terapkan ACL (iptables) — non-fatal agar server tetap jalan
echo "[*] Applying ACL rules..."
/acl.sh web || echo "[WARN] ACL failed (non-fatal, mungkin butuh NET_ADMIN)"

# Test Snort config dulu
echo "[*] Testing SNORT config..."
snort -T -c /etc/snort/snort.conf --daq-dir /usr/lib/daq 2>&1 | tail -5 || true

# Start SNORT di background
echo "[*] Starting SNORT IDS..."
mkdir -p /var/log/snort
snort -D \
  -i any \
  -c /etc/snort/snort.conf \
  -l /var/log/snort \
  -A fast \
  --daq-dir /usr/lib/daq \
  2>/var/log/snort/snort_startup.log || echo "[WARN] SNORT failed to start (non-fatal)"

# Cek apakah Snort jalan
sleep 1
if pgrep -x snort > /dev/null; then
    echo "[OK] SNORT is running (PID: $(pgrep -x snort))"
else
    echo "[WARN] SNORT is NOT running. Startup log:"
    cat /var/log/snort/snort_startup.log 2>/dev/null || true
fi

echo "[*] Starting Go HTTPS server..."
cd /app && ./server