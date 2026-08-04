# UKK Cybersecurity Docker Lab

Lab ini menyediakan dua aplikasi terpisah pada Ubuntu Server untuk skenario UKK Cybersecurity:

- **Web Internal**: `http://192.168.50.10:8080`
- **Web Vulnerable**: `http://192.168.50.10:8081`

## Fungsi Lab

- **Web Internal** digunakan untuk baseline audit, hardening, retest, dan pembuktian kondisi sebelum/sesudah perbaikan.
- **Web Vulnerable** digunakan untuk pengujian legal seperti SQL Injection, XSS, simulasi cookie theft pada data dummy, JWT exposure, IDOR, dan path traversal.
- Semua request penting dicatat agar dapat dianalisis melalui Splunk.

## Peringatan Keamanan

Lab ini sengaja dibuat rentan. Jalankan hanya pada:

- VM khusus;
- jaringan lab yang terisolasi;
- target yang telah diizinkan;
- data dan akun dummy.

Jangan mempublikasikan port `8081` langsung ke internet. Web Vulnerable hanya boleh digunakan pada jaringan UKK/laboratorium.

---

# 1. Prasyarat Ubuntu Server

Rekomendasi sistem:

```text
Ubuntu Server 22.04/24.04
IP      : 192.168.50.10/24
Gateway : 192.168.50.1
DNS     : sesuai jaringan lab
```

Pastikan IP sudah terpasang:

```bash
ip -br address
ip route
```

Script auto setup **tidak mengubah Netplan atau IP server** untuk mencegah koneksi SSH terputus.

---

# 2. Ekstrak Paket Lab

Pasang `unzip` bila belum tersedia:

```bash
sudo apt update
sudo apt install unzip -y
```

Ekstrak paket:

```bash
unzip ukk-cyber-docker-lab-auto-setup.zip
cd ukk-cyber-docker-lab
chmod +x scripts/*.sh
```

---

# 3. Auto Setup yang Disarankan

Jalankan satu perintah berikut:

```bash
sudo ./scripts/auto-setup.sh \
  --server-ip 192.168.50.10 \
  --install-dir /opt/ukk-cyber-docker-lab
```

Konfirmasi dengan `y` ketika ringkasan pemasangan ditampilkan.

## Mode Tanpa Pertanyaan

```bash
sudo ./scripts/auto-setup.sh \
  --server-ip 192.168.50.10 \
  --install-dir /opt/ukk-cyber-docker-lab \
  --non-interactive
```

## Yang Dilakukan Script

Script otomatis akan:

1. memeriksa sistem operasi Ubuntu;
2. memastikan IP `192.168.50.10` terpasang pada host;
3. memeriksa penggunaan port `8080` dan `8081`;
4. memasang paket dasar;
5. memasang Docker Engine, Buildx, dan Docker Compose plugin bila belum tersedia;
6. menyalin lab ke `/opt/ukk-cyber-docker-lab`;
7. membuat file `.env` dengan permission terbatas;
8. menyiapkan folder dan permission log;
9. memvalidasi `compose.yml`;
10. membangun dan menjalankan Web Internal serta Web Vulnerable;
11. menunggu kedua container berstatus `healthy`;
12. membuat service `ukk-cyber-lab.service` agar stack dapat aktif setelah reboot.

## Yang Sengaja Tidak Dilakukan Script

- Tidak mengubah IP atau Netplan.
- Tidak membuat DNAT MikroTik.
- Tidak mengaktifkan UFW.
- Tidak menginstal Splunk.
- Tidak menambahkan user ke grup `docker` secara otomatis.

Bagian tersebut dipisahkan karena termasuk konfigurasi infrastruktur atau task hardening UKK.

---

# 4. Pemeriksaan Setelah Setup

Masuk ke direktori instalasi:

```bash
cd /opt/ukk-cyber-docker-lab
```

Periksa status container:

```bash
sudo ./scripts/labctl.sh status
```

Jalankan health check:

```bash
sudo ./scripts/labctl.sh health
```

Alternatif pemeriksaan langsung:

```bash
sudo docker compose ps
sudo docker compose logs --tail=50
```

Hasil yang diharapkan:

```text
ukk-web-internal   running/healthy
ukk-web-vuln       running/healthy
```

Buka dari PC Admin:

```text
http://192.168.50.10:8080
http://192.168.50.10:8081
```

---

# 5. Perintah Pengelolaan Lab

Semua perintah berikut dijalankan dari:

```bash
cd /opt/ukk-cyber-docker-lab
```

## Melihat status

```bash
sudo ./scripts/labctl.sh status
```

## Health check

```bash
sudo ./scripts/labctl.sh health
```

## Menjalankan lab

```bash
sudo ./scripts/labctl.sh start
```

## Menghentikan lab

```bash
sudo ./scripts/labctl.sh stop
```

## Restart lab

```bash
sudo ./scripts/labctl.sh restart
```

## Melihat seluruh log

```bash
sudo ./scripts/labctl.sh logs
```

## Log Web Internal

```bash
sudo ./scripts/labctl.sh logs-internal
```

## Log Web Vulnerable

```bash
sudo ./scripts/labctl.sh logs-vuln
```

## Build ulang image

```bash
sudo ./scripts/labctl.sh build
```

## Reset untuk peserta berikutnya

```bash
sudo ./scripts/labctl.sh reset
```

Reset akan menghapus data latihan, database Web Vulnerable, dan log lama, kemudian mengembalikan lab ke kondisi awal.

---

# 6. Service Systemd

Periksa service:

```bash
sudo systemctl status ukk-cyber-lab.service
```

Restart stack:

```bash
sudo systemctl restart ukk-cyber-lab.service
```

Nonaktifkan auto-start:

```bash
sudo systemctl disable ukk-cyber-lab.service
```

Setelah reboot, periksa:

```bash
sudo systemctl status docker
sudo systemctl status ukk-cyber-lab.service
sudo /opt/ukk-cyber-docker-lab/scripts/labctl.sh health
```

---

# 7. Setup Manual Alternatif

Gunakan bagian ini hanya bila tidak memakai `auto-setup.sh` dan Docker sudah terpasang.

```bash
cp .env.example .env
nano .env
```

Contoh isi `.env`:

```env
SERVER_IP=192.168.50.10
WEB_INTERNAL_PORT=8080
WEB_VULN_PORT=8081
TZ=Asia/Jakarta
```

Jalankan:

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

Periksa:

```bash
docker compose ps
./scripts/healthcheck.sh
```

---

# 8. Konfigurasi MikroTik

## Web Internal

Web Internal **tidak dibuat DNAT** ke jaringan WAN.

Akses internal:

```text
http://192.168.50.10:8080
```

## Web Vulnerable

Hanya Web Vulnerable yang diteruskan melalui MikroTik:

```text
10.10.10.100:8081
        ↓ DNAT
192.168.50.10:8081
```

Contoh rule DNAT:

```mikrotik
/ip firewall nat
add chain=dstnat \
    in-interface-list=WAN \
    dst-address=10.10.10.100 \
    protocol=tcp \
    dst-port=8081 \
    action=dst-nat \
    to-addresses=192.168.50.10 \
    to-ports=8081 \
    comment="DNAT Web Vulnerable UKK"
```

Contoh firewall forward:

```mikrotik
/ip firewall filter
add chain=forward \
    in-interface-list=WAN \
    connection-nat-state=dstnat \
    protocol=tcp \
    dst-address=192.168.50.10 \
    dst-port=8081 \
    action=accept \
    comment="ALLOW DNAT Web Vulnerable"
```

---

# 9. Log untuk Splunk

Lokasi log pada host:

```text
logs/web-internal/access.log
logs/web-internal/error.log
logs/web-vuln/access.jsonl
logs/web-vuln/collector.log
```

Pantau log langsung:

```bash
tail -f logs/web-internal/access.log
```

```bash
tail -f logs/web-vuln/access.jsonl
```

```bash
tail -f logs/web-vuln/collector.log
```

Contoh konfigurasi Splunk Universal Forwarder tersedia pada:

```text
splunk/inputs.conf.example
```

Sourcetype yang disarankan:

| Log | Sourcetype |
|---|---|
| Web Internal access | `nginx:access:internal` |
| Web Internal error | `nginx:error:internal` |
| Web Vulnerable | `ukk:web:vuln:json` |
| Cookie collector | `ukk:web:collector:json` |

---

# 10. Akun dan Data Dummy

Akun diberikan oleh penguji. Seluruh akun, password, cookie, JWT, dan file hanya digunakan untuk lab dan tidak boleh digunakan pada sistem nyata.

Folder berikut khusus pelatih dan tidak diberikan kepada siswa:

```text
trainer/
```

---

# 11. Troubleshooting Singkat

## Port 8080 atau 8081 sudah digunakan

```bash
sudo ss -ltnp | grep -E ':8080|:8081'
```

Hentikan service yang bentrok atau ubah port melalui opsi setup.

## Container tidak healthy

```bash
cd /opt/ukk-cyber-docker-lab
sudo docker compose ps
sudo docker compose logs --tail=100
sudo ./scripts/labctl.sh health
```

## Docker tidak berjalan

```bash
sudo systemctl status docker
sudo systemctl restart docker
```

## Memeriksa paket Docker yang mungkin konflik

```bash
dpkg -l | grep -E 'docker|containerd|runc|podman'
```

Script berhenti jika menemukan paket runtime yang berpotensi konflik agar tidak menghapus atau merusak container lama secara otomatis.

---

# 12. Ringkasan Alamat

```text
Web Internal
http://192.168.50.10:8080

Web Vulnerable internal
http://192.168.50.10:8081

Web Vulnerable dari Kali melalui MikroTik
http://10.10.10.100:8081
```
