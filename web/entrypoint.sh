#!/bin/bash
set -e

echo "=== Starting Web Server ==="

# Terapkan ACL (iptables) — non-fatal agar server tetap jalan
echo "[*] Applying ACL rules..."
/acl.sh web || echo "[WARN] ACL failed (non-fatal, mungkin butuh NET_ADMIN)"

# Test Snort config dulu
echo "[*] Testing SNORT config..."
snort -T -c /etc/snort/snort.conf --daq-dir /usr/lib/daq 2>&1 | tail -5
SNORT_TEST=$?

if [ $SNORT_TEST -ne 0 ]; then
    echo "[WARN] Snort config test FAILED! Lihat error di atas."
fi

# Start SNORT di background
echo "[*] Starting SNORT IDS..."
mkdir -p /var/log/snort
touch /var/log/snort/alert

# List semua interfaces untuk debug
echo "[*] Available network interfaces:"
ifconfig 2>/dev/null | grep -E "^[a-z]|inet " || ip addr show 2>/dev/null | grep -E "^[0-9]+:|inet " || true

# Coba start Snort di setiap interface sampai berhasil
SNORT_STARTED=false
for IFACE in eth1 eth0; do
    echo "[*] Trying Snort on interface: $IFACE"
    snort \
      -i "$IFACE" \
      -c /etc/snort/snort.conf \
      -l /var/log/snort \
      -A fast \
      --daq-dir /usr/lib/daq \
      > /var/log/snort/snort_stdout.log 2>/var/log/snort/snort_startup.log &

    sleep 3

    if pgrep -x snort > /dev/null; then
        echo "[OK] SNORT is running on $IFACE (PID: $(pgrep -x snort))"
        SNORT_STARTED=true
        break
    else
        echo "[FAIL] Snort gagal di $IFACE"
        cat /var/log/snort/snort_startup.log 2>/dev/null | tail -5 || true
    fi
done

if [ "$SNORT_STARTED" = false ]; then
    echo "[WARN] SNORT gagal start di semua interface!"
    cat /var/log/snort/snort_startup.log 2>/dev/null || true
fi

echo "[*] Starting Go HTTPS server..."
cd /app && ./server