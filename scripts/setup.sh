#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker belum terpasang. Install Docker Engine dan Compose plugin terlebih dahulu."
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: docker compose plugin belum tersedia."
  exit 1
fi

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Membuat .env dari .env.example"
fi

SERVER_IP="$(grep -E '^SERVER_IP=' .env | cut -d= -f2-)"
if ! ip -4 addr show | grep -q "${SERVER_IP}/"; then
  echo "PERINGATAN: IP ${SERVER_IP} belum ditemukan pada Ubuntu host."
  echo "Atur Netplan Ubuntu terlebih dahulu atau ubah SERVER_IP pada file .env."
  exit 2
fi

mkdir -p logs/web-internal logs/web-vuln
sudo chown -R 101:101 logs/web-internal
sudo chown -R 10001:10001 logs/web-vuln
sudo chmod -R u+rwX,go-rwx logs/web-internal logs/web-vuln

echo "Membangun image lab..."
docker compose build --pull

echo "Menjalankan lab..."
docker compose up -d

echo
docker compose ps

echo
"$ROOT_DIR/scripts/healthcheck.sh"
