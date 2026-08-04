#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "ERROR: .env tidak ditemukan. Jalankan auto-setup.sh atau setup.sh terlebih dahulu." >&2
  exit 1
fi

if [[ "${EUID}" -eq 0 ]]; then
  DOCKER=(docker)
elif docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
else
  echo "ERROR: tidak dapat mengakses Docker daemon. Gunakan sudo." >&2
  exit 1
fi

compose() { "${DOCKER[@]}" compose --env-file .env -f compose.yml "$@"; }

case "${1:-help}" in
  start)
    compose up -d --remove-orphans
    ;;
  stop)
    compose stop
    ;;
  restart)
    compose restart
    ;;
  status)
    compose ps
    ;;
  health)
    "$ROOT_DIR/scripts/healthcheck.sh"
    ;;
  logs)
    compose logs -f --tail=100
    ;;
  logs-internal)
    compose logs -f --tail=100 web-internal
    ;;
  logs-vuln)
    compose logs -f --tail=100 web-vuln
    ;;
  build)
    compose build --pull
    compose up -d --remove-orphans
    ;;
  reset)
    "$ROOT_DIR/scripts/reset-lab.sh"
    ;;
  backup)
    stamp="$(date +%Y%m%d-%H%M%S)"
    out="${2:-$ROOT_DIR/backups/ukk-lab-${stamp}.tar.gz}"
    mkdir -p "$(dirname "$out")"
    compose stop
    tar -czf "$out" .env compose.yml logs web-internal web-vuln splunk trainer scripts README.md SCENARIO-STUDENT.md
    compose start
    echo "Backup dibuat: $out"
    ;;
  help|*)
    cat <<HELP
UKK Cyber Lab Control

Usage: sudo ./scripts/labctl.sh COMMAND

Commands:
  start          Jalankan lab
  stop           Hentikan container tanpa menghapus data
  restart        Restart container
  status         Tampilkan status
  health         Uji kedua layanan
  logs           Ikuti seluruh log
  logs-internal  Ikuti log Web Internal
  logs-vuln      Ikuti log Web Vulnerable
  build          Build ulang dan jalankan
  reset          Hapus data/log latihan dan kembali ke kondisi awal
  backup [FILE]  Backup konfigurasi dan data lab
HELP
    ;;
esac
