#!/bin/bash
# ACL Rules menggunakan iptables

MODE=$1

# Flush semua rules lama
iptables -F
iptables -X

echo "[ACL] Setting up rules for: $MODE"

if [ "$MODE" = "web" ]; then

    # === WEB SERVER RULES ===

    # Izinkan koneksi yang sudah established
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Izinkan loopback
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # Izinkan HTTPS dari siapapun
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT

    # Izinkan HTTP (untuk redirect ke HTTPS)
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT

    # Izinkan koneksi ke DB hanya ke backend_net
    iptables -A OUTPUT -p tcp -d 172.21.0.0/24 --dport 3306 -j ACCEPT

    # BLOCK akses langsung ke MySQL dari luar
    iptables -A INPUT -p tcp --dport 3306 -j DROP

    # ICMP: izinkan ping tapi limit (anti flood)
    iptables -A INPUT -p icmp --icmp-type echo-request \
        -m limit --limit 5/min --limit-burst 10 -j ACCEPT
    iptables -A INPUT -p icmp -j DROP

    # Block port scan (SYN flood)
    iptables -A INPUT -p tcp --syn \
        -m limit --limit 20/s --limit-burst 50 -j ACCEPT
    iptables -A INPUT -p tcp --syn -j DROP

    # Default policy: drop semua yang tidak diizinkan
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

elif [ "$MODE" = "db" ]; then

    # === DB SERVER RULES ===

    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT

    # Hanya izinkan MySQL dari web server
    iptables -A INPUT -p tcp -s 172.21.0.10 --dport 3306 -j ACCEPT

    # Block semua akses MySQL dari IP lain
    iptables -A INPUT -p tcp --dport 3306 -j DROP

    # ICMP sangat terbatas
    iptables -A INPUT -p icmp --icmp-type echo-request \
        -m limit --limit 2/min -j ACCEPT
    iptables -A INPUT -p icmp -j DROP

    # Default drop
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

fi

echo "[ACL] Rules applied!"
iptables -L -n --line-numbers