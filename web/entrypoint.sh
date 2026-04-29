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
touch /var/log/snort/alert

# List semua interfaces untuk debug
echo "[*] Available network interfaces:"
ip addr show | grep -E "^[0-9]+:|inet " || ifconfig 2>/dev/null || true

# Coba start Snort di setiap interface sampai berhasil
SNORT_STARTED=false
for IFACE in eth1 eth0 lo; do
    echo "[*] Trying Snort on interface: $IFACE"
    snort \
      -i "$IFACE" \
      -c /etc/snort/snort.conf \
      -l /var/log/snort \
      -A fast \
      --daq-dir /usr/lib/daq \
      > /var/log/snort/snort_stdout.log 2>/var/log/snort/snort_startup.log &

    sleep 2

    if pgrep -x snort > /dev/null; then
        echo "[OK] SNORT is running on $IFACE (PID: $(pgrep -x snort))"
        SNORT_STARTED=true
        break
    else
        echo "[FAIL] Snort gagal di $IFACE, coba interface lain..."
        cat /var/log/snort/snort_startup.log 2>/dev/null || true
    fi
done

if [ "$SNORT_STARTED" = false ]; then
    echo "[WARN] SNORT gagal start di semua interface!"
    echo "[WARN] Startup log terakhir:"
    cat /var/log/snort/snort_startup.log 2>/dev/null || true
fi

echo "[*] Starting Go HTTPS server..."
cd /app && ./server