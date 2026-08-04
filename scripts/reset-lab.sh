#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "${EUID}" -eq 0 ]]; then
  DOCKER=(docker)
elif docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
else
  echo "ERROR: tidak dapat mengakses Docker daemon." >&2
  exit 1
fi
compose() { "${DOCKER[@]}" compose --env-file .env -f compose.yml "$@"; }

read -r -p "Reset akan menghapus database latihan dan seluruh log. Lanjutkan? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Reset dibatalkan."; exit 0; }

echo "Menghentikan container dan menghapus volume data Web Lab..."
compose down -v --remove-orphans

find logs/web-internal -type f -delete 2>/dev/null || true
find logs/web-vuln -type f -delete 2>/dev/null || true
if [[ "${EUID}" -eq 0 ]]; then
  chown -R 101:101 logs/web-internal
  chown -R 10001:10001 logs/web-vuln
else
  sudo chown -R 101:101 logs/web-internal
  sudo chown -R 10001:10001 logs/web-vuln
fi

echo "Menjalankan kondisi awal kembali..."
compose up -d --build --remove-orphans
sleep 5
"$ROOT_DIR/scripts/healthcheck.sh"
