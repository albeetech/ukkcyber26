#!/usr/bin/env bash
set -Eeuo pipefail

# UKK Cybersecurity Docker Lab - automatic installer for Ubuntu Server.
# Safe defaults:
# - Does not change Netplan/static IP automatically.
# - Does not publish services on 0.0.0.0.
# - Does not configure UFW because firewall hardening is part of the UKK task.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_SERVER_IP="192.168.50.10"
SERVER_IP=""
WEB_INTERNAL_PORT="8080"
WEB_VULN_PORT="8081"
TZ_VALUE="Asia/Jakarta"
INSTALL_DIR="$ROOT_DIR"
INSTALL_DOCKER="yes"
INSTALL_SYSTEMD="yes"
ADD_USER_TO_DOCKER="no"
FORCE_REBUILD="no"
NON_INTERACTIVE="no"

log()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<USAGE
Usage:
  sudo ./scripts/auto-setup.sh [options]

Options:
  --server-ip IP          IP Ubuntu Server yang dipakai untuk binding container.
                          Default: auto-detect 192.168.50.x, lalu ${DEFAULT_SERVER_IP}.
  --internal-port PORT    Port Web Internal. Default: 8080.
  --vuln-port PORT        Port Web Vulnerable. Default: 8081.
  --timezone TZ           Timezone container. Default: Asia/Jakarta.
  --install-dir PATH      Salin lab ke direktori lain, contoh /opt/ukk-cyber-docker-lab.
  --skip-docker-install   Jangan memasang Docker jika belum tersedia.
  --skip-systemd          Jangan membuat service systemd lab.
  --add-user-to-docker    Tambahkan user pemanggil sudo ke grup docker.
                          PERINGATAN: grup docker setara hak root pada host.
  --force-rebuild         Build ulang image tanpa cache.
  --non-interactive       Jangan meminta konfirmasi.
  -h, --help              Tampilkan bantuan.

Contoh yang disarankan:
  sudo ./scripts/auto-setup.sh \\
    --server-ip 192.168.50.10 \\
    --install-dir /opt/ukk-cyber-docker-lab
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server-ip) SERVER_IP="${2:?IP belum diisi}"; shift 2 ;;
    --internal-port) WEB_INTERNAL_PORT="${2:?Port belum diisi}"; shift 2 ;;
    --vuln-port) WEB_VULN_PORT="${2:?Port belum diisi}"; shift 2 ;;
    --timezone) TZ_VALUE="${2:?Timezone belum diisi}"; shift 2 ;;
    --install-dir) INSTALL_DIR="${2:?Path belum diisi}"; shift 2 ;;
    --skip-docker-install) INSTALL_DOCKER="no"; shift ;;
    --skip-systemd) INSTALL_SYSTEMD="no"; shift ;;
    --add-user-to-docker) ADD_USER_TO_DOCKER="yes"; shift ;;
    --force-rebuild) FORCE_REBUILD="yes"; shift ;;
    --non-interactive) NON_INTERACTIVE="yes"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Opsi tidak dikenal: $1" ;;
  esac
done

[[ "${EUID}" -eq 0 ]] || die "Jalankan dengan sudo: sudo ./scripts/auto-setup.sh ..."

[[ -r /etc/os-release ]] || die "/etc/os-release tidak ditemukan."
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || die "Script ini ditujukan untuk Ubuntu Server. OS terdeteksi: ${PRETTY_NAME:-unknown}"

validate_port() {
  local value="$1" name="$2"
  [[ "$value" =~ ^[0-9]+$ ]] || die "$name harus berupa angka."
  (( value >= 1024 && value <= 65535 )) || die "$name harus berada pada rentang 1024-65535."
}
validate_port "$WEB_INTERNAL_PORT" "Port Web Internal"
validate_port "$WEB_VULN_PORT" "Port Web Vulnerable"
[[ "$WEB_INTERNAL_PORT" != "$WEB_VULN_PORT" ]] || die "Port Web Internal dan Web Vulnerable tidak boleh sama."

is_valid_ipv4() {
  local ip="$1" IFS=.
  local -a octets
  read -r -a octets <<< "$ip"
  [[ ${#octets[@]} -eq 4 ]] || return 1
  local o
  for o in "${octets[@]}"; do
    [[ "$o" =~ ^[0-9]+$ ]] || return 1
    (( o >= 0 && o <= 255 )) || return 1
  done
}

if [[ -z "$SERVER_IP" ]]; then
  SERVER_IP="$(ip -o -4 addr show scope global 2>/dev/null | awk '$4 ~ /^192\.168\.50\./ {sub(/\/.*/,"",$4); print $4; exit}')"
  if [[ -z "$SERVER_IP" ]]; then
    SERVER_IP="$DEFAULT_SERVER_IP"
  fi
fi
is_valid_ipv4 "$SERVER_IP" || die "SERVER_IP tidak valid: $SERVER_IP"

if ! ip -o -4 addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fxq "$SERVER_IP"; then
  die "IP ${SERVER_IP} tidak ditemukan pada Ubuntu host. Atur Netplan terlebih dahulu; script sengaja tidak mengubah jaringan agar koneksi SSH tidak terputus."
fi

if ss -H -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)$WEB_INTERNAL_PORT$"; then
  warn "Port ${WEB_INTERNAL_PORT} sedang digunakan. Jika bukan container lab lama, setup dapat gagal."
fi
if ss -H -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)$WEB_VULN_PORT$"; then
  warn "Port ${WEB_VULN_PORT} sedang digunakan. Jika bukan container lab lama, setup dapat gagal."
fi

if [[ "$NON_INTERACTIVE" != "yes" ]]; then
  cat <<SUMMARY

Rencana pemasangan:
  OS              : ${PRETTY_NAME}
  Direktori       : ${INSTALL_DIR}
  Server IP       : ${SERVER_IP}
  Web Internal    : http://${SERVER_IP}:${WEB_INTERNAL_PORT}
  Web Vulnerable  : http://${SERVER_IP}:${WEB_VULN_PORT}
  Install Docker  : ${INSTALL_DOCKER}
  Service systemd : ${INSTALL_SYSTEMD}

Script tidak mengubah IP/Netplan dan tidak mengaktifkan UFW.
SUMMARY
  read -r -p "Lanjutkan setup? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || die "Dibatalkan pengguna."
fi

export DEBIAN_FRONTEND=noninteractive

install_base_packages() {
  log "Memasang paket dasar..."
  apt-get update
  apt-get install -y ca-certificates curl gnupg unzip jq iproute2
}

install_docker_official() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    ok "Docker Engine dan Compose plugin sudah tersedia."
    return
  fi

  [[ "$INSTALL_DOCKER" == "yes" ]] || die "Docker/Compose belum tersedia dan pemasangan otomatis dinonaktifkan."

  log "Memasang Docker Engine dari repository resmi Docker..."
  install_base_packages

  # Abort when known conflicting packages are installed; do not remove automatically.
  local conflicts=()
  local pkg
  for pkg in docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc; do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
      conflicts+=("$pkg")
    fi
  done
  if (( ${#conflicts[@]} > 0 )); then
    die "Paket berpotensi konflik terdeteksi: ${conflicts[*]}. Hapus/putuskan secara manual agar data Docker lama tidak terhapus tanpa sengaja."
  fi

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  cat > /etc/apt/sources.list.d/docker.sources <<DOCKER_REPO
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
DOCKER_REPO

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  docker version >/dev/null
  docker compose version >/dev/null
  ok "Docker Engine dan Compose plugin berhasil dipasang."
}

copy_lab_if_needed() {
  if [[ "$INSTALL_DIR" == "$ROOT_DIR" ]]; then
    return
  fi
  log "Menyalin lab ke ${INSTALL_DIR}..."
  mkdir -p "$INSTALL_DIR"
  # Exclude runtime state and local environment from source copy.
  tar -C "$ROOT_DIR" \
      --exclude='./.env' \
      --exclude='./logs/web-internal/*' \
      --exclude='./logs/web-vuln/*' \
      --exclude='./.git' \
      -cf - . | tar -C "$INSTALL_DIR" -xf -
  ROOT_DIR="$INSTALL_DIR"
}

write_env() {
  cat > "$ROOT_DIR/.env" <<ENV_FILE
SERVER_IP=${SERVER_IP}
WEB_INTERNAL_PORT=${WEB_INTERNAL_PORT}
WEB_VULN_PORT=${WEB_VULN_PORT}
TZ=${TZ_VALUE}
ENV_FILE
  chmod 600 "$ROOT_DIR/.env"
  ok "File .env dibuat."
}

prepare_directories() {
  mkdir -p "$ROOT_DIR/logs/web-internal" "$ROOT_DIR/logs/web-vuln"
  chown -R 101:101 "$ROOT_DIR/logs/web-internal"
  chown -R 10001:10001 "$ROOT_DIR/logs/web-vuln"
  chmod 750 "$ROOT_DIR/logs" "$ROOT_DIR/logs/web-internal" "$ROOT_DIR/logs/web-vuln"
  find "$ROOT_DIR/scripts" -maxdepth 1 -type f -name '*.sh' -exec chmod 750 {} +
}

install_systemd_unit() {
  [[ "$INSTALL_SYSTEMD" == "yes" ]] || return
  cat > /etc/systemd/system/ukk-cyber-lab.service <<UNIT
[Unit]
Description=UKK Cybersecurity Docker Lab
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=${ROOT_DIR}
ExecStart=/usr/bin/docker compose --env-file ${ROOT_DIR}/.env -f ${ROOT_DIR}/compose.yml up -d
ExecStop=/usr/bin/docker compose --env-file ${ROOT_DIR}/.env -f ${ROOT_DIR}/compose.yml stop
RemainAfterExit=yes
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable ukk-cyber-lab.service
  ok "Service systemd ukk-cyber-lab.service dibuat dan diaktifkan."
}

add_user_to_docker_group() {
  [[ "$ADD_USER_TO_DOCKER" == "yes" ]] || return
  local target_user="${SUDO_USER:-}"
  [[ -n "$target_user" && "$target_user" != "root" ]] || { warn "Tidak dapat menentukan user non-root pemanggil sudo."; return; }
  getent group docker >/dev/null || groupadd docker
  usermod -aG docker "$target_user"
  warn "User ${target_user} ditambahkan ke grup docker. Logout/login diperlukan. Grup docker memberikan hak setara root."
}

start_lab() {
  cd "$ROOT_DIR"
  log "Memvalidasi file Compose..."
  docker compose --env-file .env config >/dev/null

  if [[ "$FORCE_REBUILD" == "yes" ]]; then
    log "Membangun image tanpa cache..."
    docker compose --env-file .env build --pull --no-cache
  else
    log "Membangun image lab..."
    docker compose --env-file .env build --pull
  fi

  log "Menjalankan container..."
  docker compose --env-file .env up -d --remove-orphans
}

wait_health() {
  local attempts=30
  local delay=3
  log "Menunggu health check container..."
  for ((i=1; i<=attempts; i++)); do
    local internal_status vuln_status
    internal_status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' ukk-web-internal 2>/dev/null || true)"
    vuln_status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' ukk-web-vuln 2>/dev/null || true)"
    if [[ "$internal_status" == "healthy" && "$vuln_status" == "healthy" ]]; then
      ok "Kedua container berstatus healthy."
      return
    fi
    printf '  Percobaan %02d/%02d: internal=%s vuln=%s\n' "$i" "$attempts" "${internal_status:-belum tersedia}" "${vuln_status:-belum tersedia}"
    sleep "$delay"
  done
  docker compose --env-file "$ROOT_DIR/.env" -f "$ROOT_DIR/compose.yml" ps || true
  docker compose --env-file "$ROOT_DIR/.env" -f "$ROOT_DIR/compose.yml" logs --tail=80 || true
  die "Container belum healthy setelah $((attempts*delay)) detik. Periksa log di atas."
}

install_base_packages
install_docker_official
copy_lab_if_needed
write_env
prepare_directories
add_user_to_docker_group
start_lab
wait_health
install_systemd_unit

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/healthcheck.sh"

echo
ok "AUTO SETUP SELESAI"
cat <<RESULT

Alamat layanan:
  Web Internal   : http://${SERVER_IP}:${WEB_INTERNAL_PORT}
  Web Vulnerable : http://${SERVER_IP}:${WEB_VULN_PORT}

Perintah administrasi:
  cd ${ROOT_DIR}
  sudo ./scripts/labctl.sh status
  sudo ./scripts/labctl.sh health
  sudo ./scripts/labctl.sh logs
  sudo ./scripts/labctl.sh reset

Catatan jaringan:
  - Jangan buat DNAT WAN untuk port ${WEB_INTERNAL_PORT}.
  - DNAT hanya port ${WEB_VULN_PORT} ke ${SERVER_IP}:${WEB_VULN_PORT}.
  - Lab rentan hanya boleh berada pada jaringan ujian yang terisolasi.
RESULT
