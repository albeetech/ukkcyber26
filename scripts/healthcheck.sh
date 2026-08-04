#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

[[ -f .env ]] || { echo "ERROR: .env tidak ditemukan." >&2; exit 1; }
get_env() { awk -F= -v key="$1" '$1==key {print substr($0,index($0,"=")+1)}' .env | tail -n1; }
SERVER_IP="$(get_env SERVER_IP)"
INTERNAL_PORT="$(get_env WEB_INTERNAL_PORT)"
VULN_PORT="$(get_env WEB_VULN_PORT)"

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

failed=0
printf '%-24s' "Web Internal"
if curl -fsS --max-time 5 "http://${SERVER_IP}:${INTERNAL_PORT}/health.txt" >/dev/null; then
  echo "OK"
else
  echo "GAGAL"; failed=1
fi
printf '%-24s' "Web Vulnerable"
if curl -fsS --max-time 5 "http://${SERVER_IP}:${VULN_PORT}/health" >/dev/null; then
  echo "OK"
else
  echo "GAGAL"; failed=1
fi
printf '%-24s' "Container internal"
internal_status="$("${DOCKER[@]}" inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' ukk-web-internal 2>/dev/null || true)"
[[ "$internal_status" == "healthy" ]] && echo "OK" || { echo "${internal_status:-TIDAK ADA}"; failed=1; }
printf '%-24s' "Container vulnerable"
vuln_status="$("${DOCKER[@]}" inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' ukk-web-vuln 2>/dev/null || true)"
[[ "$vuln_status" == "healthy" ]] && echo "OK" || { echo "${vuln_status:-TIDAK ADA}"; failed=1; }

echo "Internal : http://${SERVER_IP}:${INTERNAL_PORT}"
echo "Web Lab  : http://${SERVER_IP}:${VULN_PORT}"
exit "$failed"
