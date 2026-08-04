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
