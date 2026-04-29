#!/bin/bash
set -e

echo "=== Starting Web Server ==="

# Terapkan ACL (iptables)
echo "[*] Applying ACL rules..."
/acl.sh web || echo "[WARN] ACL failed (non-fatal)"

# Test Snort config
echo "[*] Testing SNORT config..."
snort -T -c /etc/snort/snort.conf --daq pcap --daq-dir /usr/lib/daq 2>&1 | tail -5 || true

# Setup Snort
echo "[*] Starting SNORT IDS/IPS..."
mkdir -p /var/log/snort
touch /var/log/snort/alert

# Show interfaces
echo "[*] Network interfaces:"
ifconfig 2>/dev/null | grep -E "^[a-z]|inet " || true

# Start Snort di IDS mode (pcap passive)
SNORT_STARTED=false
for IFACE in eth1 eth0; do
    echo "[*] Trying Snort on interface: $IFACE"
    snort \
      -i "$IFACE" \
      --daq pcap \
      --daq-dir /usr/lib/daq \
      -c /etc/snort/snort.conf \
      -l /var/log/snort \
      -A fast \
      > /var/log/snort/snort_stdout.log 2>/var/log/snort/snort_startup.log &

    sleep 3

    if pgrep -x snort > /dev/null; then
        echo "[OK] SNORT IDS running on $IFACE (PID: $(pgrep -x snort))"
        SNORT_STARTED=true
        break
    else
        echo "[FAIL] Snort gagal di $IFACE"
        cat /var/log/snort/snort_startup.log 2>/dev/null | tail -3 || true
    fi
done

if [ "$SNORT_STARTED" = false ]; then
    echo "[WARN] SNORT tidak bisa start!"
fi

# =============================================
# REACTIVE IPS — Auto-block attacker IP via iptables
# Saat Snort mendeteksi serangan [IPS-...], script ini
# langsung memblokir IP penyerang menggunakan iptables.
# =============================================
echo "[*] Starting Reactive IPS watcher..."

(
    # Whitelist IP yang tidak boleh di-block
    WHITELIST="172.20.0.10 172.21.0.10 172.21.0.20 127.0.0.1"

    tail -F /var/log/snort/alert 2>/dev/null | while read -r line; do
        # Hanya proses alert yang mengandung [IPS-] (rule drop)
        if echo "$line" | grep -q "\[IPS-"; then
            # Ambil source IP (IP pertama dalam baris alert)
            SRC_IP=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)

            if [ -n "$SRC_IP" ]; then
                # Cek apakah IP ada di whitelist
                IS_WHITELISTED=false
                for WL in $WHITELIST; do
                    if [ "$SRC_IP" = "$WL" ]; then
                        IS_WHITELISTED=true
                        break
                    fi
                done

                if [ "$IS_WHITELISTED" = false ]; then
                    # Cek apakah sudah di-block sebelumnya
                    if ! iptables -C INPUT -s "$SRC_IP" -j DROP 2>/dev/null; then
                        iptables -I INPUT 1 -s "$SRC_IP" -j DROP
                        echo "[IPS-BLOCK] IP $SRC_IP DIBLOKIR! Alert: $(echo "$line" | grep -oP '\[IPS-[^\]]+\]')"
                    fi
                fi
            fi
        fi
    done
) &

echo "[OK] Reactive IPS watcher aktif (PID: $!)"

echo "[*] Starting Go HTTPS server..."
cd /app && ./server