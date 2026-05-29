#!/usr/bin/env bash
# Generates a self-signed TLS cert for the demo (valid for "localhost").
# Run this once before `docker compose up`.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p certs

if [[ -f certs/localhost.crt && -f certs/localhost.key ]]; then
  echo "certs/localhost.{crt,key} already exist — delete them to regenerate."
  exit 0
fi

openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout certs/localhost.key \
  -out certs/localhost.crt \
  -days 365 \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:keycloak,IP:127.0.0.1"

# Make the key world-readable so the non-root user inside the containers can read it.
chmod 644 certs/localhost.key

echo "Generated self-signed cert in ./certs (CN=localhost, valid 365 days)."
