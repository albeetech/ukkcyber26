#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
SERVER_IP="$(grep -E '^SERVER_IP=' .env | cut -d= -f2-)"
INTERNAL_PORT="$(grep -E '^WEB_INTERNAL_PORT=' .env | cut -d= -f2-)"
VULN_PORT="$(grep -E '^WEB_VULN_PORT=' .env | cut -d= -f2-)"

printf '%-24s' "Web Internal"
curl -fsS --max-time 5 "http://${SERVER_IP}:${INTERNAL_PORT}/health.txt" >/dev/null && echo "OK" || echo "GAGAL"
printf '%-24s' "Web Vulnerable"
curl -fsS --max-time 5 "http://${SERVER_IP}:${VULN_PORT}/health" >/dev/null && echo "OK" || echo "GAGAL"
printf '%-24s' "Container status"
docker compose ps --format json | grep -q 'running' && echo "OK" || echo "PERIKSA"

echo "Internal : http://${SERVER_IP}:${INTERNAL_PORT}"
echo "Web Lab  : http://${SERVER_IP}:${VULN_PORT}"
