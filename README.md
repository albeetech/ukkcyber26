# UKK Cybersecurity Docker Lab

Lab ini menyediakan dua aplikasi terpisah pada Ubuntu Server `192.168.50.10`:

- **Web Internal**: `http://192.168.50.10:8080`
- **Web Vulnerable**: `http://192.168.50.10:8081`

## Tujuan

- Web Internal digunakan untuk baseline audit, hardening, retest, dan pembuktian before/after.
- Web Vulnerable digunakan untuk pengujian legal seperti SQL injection, XSS, simulasi cookie exfiltration, JWT, IDOR, dan path traversal.
- Semua request dicatat untuk analisis Splunk.

## Keamanan Lab

Lab sengaja rentan. Jalankan hanya pada VM khusus, jaringan terisolasi, dan target yang diizinkan. Jangan mempublikasikan port 8081 ke internet. Database Web Lab menggunakan SQLite di volume Docker dan seluruh data bersifat dummy.


## Auto Setup Satu Perintah

Untuk Ubuntu Server yang sudah memiliki IP `192.168.50.10/24`, jalankan:

```bash
chmod +x scripts/*.sh
sudo ./scripts/auto-setup.sh \
  --server-ip 192.168.50.10 \
  --install-dir /opt/ukk-cyber-docker-lab
```

Script otomatis akan:

1. memeriksa Ubuntu dan IP server;
2. memasang Docker Engine serta Compose plugin dari repository resmi jika belum tersedia;
3. membuat `.env`;
4. menyiapkan permission log;
5. memvalidasi Compose;
6. build dan menjalankan kedua container;
7. menunggu status `healthy`;
8. membuat service `ukk-cyber-lab.service` agar lab aktif setelah reboot.

Script **tidak mengubah Netplan/IP** dan **tidak mengaktifkan UFW**, karena keduanya dapat memutus akses SSH dan merupakan bagian dari task hardening UKK.

Perintah pengelolaan:

```bash
sudo /opt/ukk-cyber-docker-lab/scripts/labctl.sh status
sudo /opt/ukk-cyber-docker-lab/scripts/labctl.sh health
sudo /opt/ukk-cyber-docker-lab/scripts/labctl.sh logs
sudo /opt/ukk-cyber-docker-lab/scripts/labctl.sh reset
```

Panduan lengkap tersedia pada `AUTO-SETUP.md`.

## Persiapan Ubuntu

Pastikan host memiliki IP:

```text
192.168.50.10/24
Gateway 192.168.50.1
```

Salin konfigurasi:

```bash
cp .env.example .env
nano .env
```

Jalankan:

```bash
./scripts/setup.sh
```

Periksa:

```bash
docker compose ps
./scripts/healthcheck.sh
```

Reset lab:

```bash
./scripts/reset-lab.sh
```

## Log

- `logs/web-internal/access.log`
- `logs/web-internal/error.log`
- `logs/web-vuln/access.jsonl`
- `logs/web-vuln/collector.log`

Contoh Splunk Universal Forwarder tersedia di `splunk/inputs.conf.example`.

## Akun Dummy

Akun diberikan oleh penguji. Seluruh akun hanya untuk lab dan tidak boleh digunakan pada sistem nyata.
