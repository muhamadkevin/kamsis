#!/bin/bash
# ACL Rules untuk DB Server menggunakan iptables

# Flush semua rules lama
iptables -F
iptables -X

echo "[ACL] Setting up DB server rules..."

# === DB SERVER RULES ===

# Izinkan koneksi yang sudah established
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Izinkan loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Hanya izinkan MySQL dari web server (172.21.0.10)
iptables -A INPUT -p tcp -s 172.21.0.10 --dport 3306 -j ACCEPT

# Block semua akses MySQL dari IP lain
iptables -A INPUT -p tcp --dport 3306 -j DROP

# ICMP sangat terbatas (anti flood)
iptables -A INPUT -p icmp --icmp-type echo-request \
    -m limit --limit 2/min -j ACCEPT
iptables -A INPUT -p icmp -j DROP

# Default drop semua yang tidak diizinkan
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

echo "[ACL] DB rules applied!"
iptables -L -n --line-numbers
