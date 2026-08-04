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
  echo "ERROR: Docker daemon tidak dapat diakses. Jalankan auto-setup.sh atau gunakan sudo." >&2
  exit 1
fi

compose() { "${DOCKER[@]}" compose --env-file .env -f compose.yml "$@"; }

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker belum terpasang. Jalankan: sudo ./scripts/auto-setup.sh" >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: Docker Compose plugin belum tersedia. Jalankan auto-setup.sh." >&2
  exit 1
fi

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Membuat .env dari .env.example"
fi

# Read .env safely without executing it.
SERVER_IP="$(awk -F= '$1=="SERVER_IP" {print substr($0,index($0,"=")+1)}' .env | tail -n1)"
[[ -n "$SERVER_IP" ]] || { echo "ERROR: SERVER_IP kosong pada .env" >&2; exit 1; }

if ! ip -o -4 addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fxq "$SERVER_IP"; then
  echo "ERROR: IP ${SERVER_IP} belum ditemukan pada Ubuntu host." >&2
  echo "Atur Netplan atau ubah SERVER_IP pada .env." >&2
  exit 2
fi

mkdir -p logs/web-internal logs/web-vuln
if [[ "${EUID}" -eq 0 ]]; then
  chown -R 101:101 logs/web-internal
  chown -R 10001:10001 logs/web-vuln
else
  sudo chown -R 101:101 logs/web-internal
  sudo chown -R 10001:10001 logs/web-vuln
fi
chmod 750 logs logs/web-internal logs/web-vuln

echo "Memvalidasi Compose..."
compose config >/dev/null

echo "Membangun image lab..."
compose build --pull

echo "Menjalankan lab..."
compose up -d --remove-orphans

echo
compose ps

echo
"$ROOT_DIR/scripts/healthcheck.sh"
