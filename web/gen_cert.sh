#!/bin/bash
# Generate self-signed SSL certificate untuk HTTPS
# Script ini bisa dijalankan manual di luar Docker jika dibutuhkan

set -e

CERT_DIR="./certs"
mkdir -p "$CERT_DIR"

echo "[*] Generating self-signed SSL certificate..."

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$CERT_DIR/key.pem" \
    -out "$CERT_DIR/cert.pem" \
    -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Kamsis/CN=localhost"

echo "[*] Certificate generated!"
echo "    - Cert: $CERT_DIR/cert.pem"
echo "    - Key:  $CERT_DIR/key.pem"
