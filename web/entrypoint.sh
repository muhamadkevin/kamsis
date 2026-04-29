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
echo "[*] Starting SNORT..."
mkdir -p /var/log/snort
touch /var/log/snort/alert

# Show interfaces
echo "[*] Network interfaces:"
ifconfig 2>/dev/null | grep -E "^[a-z]|inet " || true

# =============================================
# COBA IPS MODE (inline dengan NFQUEUE)
# =============================================
SNORT_STARTED=false

echo "[*] Attempting IPS mode (inline/nfq)..."

# Tambah iptables NFQUEUE untuk port 80 (HTTP only, HTTPS tidak bisa diinspeksi)
iptables -I INPUT 1 -p tcp --dport 80 -j NFQUEUE --queue-num 0 2>/dev/null || true

# Start Snort dalam inline mode
snort -Q \
  --daq nfq \
  --daq-var queue=0 \
  --daq-dir /usr/lib/daq \
  -c /etc/snort/snort.conf \
  -l /var/log/snort \
  -A fast \
  > /var/log/snort/snort_stdout.log 2>/var/log/snort/snort_startup.log &

sleep 3

if pgrep -x snort > /dev/null; then
    echo "[OK] SNORT IPS running (PID: $(pgrep -x snort)) — DROP rules aktif!"
    SNORT_STARTED=true
else
    echo "[WARN] IPS mode gagal, removing NFQUEUE rule..."
    iptables -D INPUT -p tcp --dport 80 -j NFQUEUE --queue-num 0 2>/dev/null || true
    cat /var/log/snort/snort_startup.log 2>/dev/null | tail -3 || true
fi

# =============================================
# FALLBACK: IDS MODE (passive dengan pcap)
# =============================================
if [ "$SNORT_STARTED" = false ]; then
    echo "[*] Falling back to IDS mode (pcap/passive)..."

    for IFACE in eth1 eth0; do
        echo "[*] Trying IDS on interface: $IFACE"
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
            echo "[OK] SNORT IDS running on $IFACE (PID: $(pgrep -x snort)) — ALERT only"
            SNORT_STARTED=true
            break
        else
            echo "[FAIL] Snort gagal di $IFACE"
            cat /var/log/snort/snort_startup.log 2>/dev/null | tail -3 || true
        fi
    done
fi

if [ "$SNORT_STARTED" = false ]; then
    echo "[WARN] SNORT tidak bisa start sama sekali!"
fi

echo "[*] Starting Go HTTPS server..."
cd /app && ./server