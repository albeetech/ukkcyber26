#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Menghentikan container dan menghapus volume data Web Lab..."
docker compose down -v --remove-orphans

sudo find logs/web-internal -type f -delete 2>/dev/null || true
sudo find logs/web-vuln -type f -delete 2>/dev/null || true
sudo chown -R 101:101 logs/web-internal
sudo chown -R 10001:10001 logs/web-vuln

echo "Menjalankan kondisi awal kembali..."
docker compose up -d --build
sleep 5
"$ROOT_DIR/scripts/healthcheck.sh"
