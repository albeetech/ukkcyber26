# Auto Setup UKK Cybersecurity Docker Lab

## Prasyarat

- Ubuntu Server 22.04/24.04 atau versi Ubuntu yang masih didukung.
- IP server sudah dikonfigurasi, direkomendasikan `192.168.50.10/24`.
- Gateway server `192.168.50.1`.
- Akses internet sementara untuk mengunduh paket dan image.
- User memiliki akses `sudo`.

> Script tidak mengubah Netplan secara otomatis untuk mencegah koneksi SSH terputus.

## Instalasi Otomatis yang Disarankan

Masuk ke folder hasil ekstraksi:

```bash
cd ukk-cyber-docker-lab
chmod +x scripts/*.sh
```

Jalankan:

```bash
sudo ./scripts/auto-setup.sh \
  --server-ip 192.168.50.10 \
  --install-dir /opt/ukk-cyber-docker-lab
```

Konfirmasi dengan `y` saat ringkasan pemasangan tampil.

## Mode Tanpa Pertanyaan

```bash
sudo ./scripts/auto-setup.sh \
  --server-ip 192.168.50.10 \
  --install-dir /opt/ukk-cyber-docker-lab \
  --non-interactive
```

## Yang Dilakukan Script

1. Memastikan sistem operasi Ubuntu.
2. Memastikan IP server benar-benar terpasang pada interface host.
3. Memeriksa port 8080 dan 8081.
4. Memasang paket dasar.
5. Memasang Docker Engine, Buildx, dan Compose plugin dari repository resmi jika belum ada.
6. Menyalin lab ke `/opt/ukk-cyber-docker-lab`.
7. Membuat `.env` dengan permission `600`.
8. Menyiapkan folder dan ownership log.
9. Memvalidasi `compose.yml`.
10. Build dan menjalankan Web Internal serta Web Vulnerable.
11. Menunggu kedua container berstatus `healthy`.
12. Membuat `ukk-cyber-lab.service` agar stack dapat aktif setelah reboot.

## Yang Sengaja Tidak Dilakukan

- Tidak mengubah IP atau Netplan.
- Tidak membuat DNAT MikroTik.
- Tidak mengaktifkan UFW.
- Tidak menginstal Splunk.
- Tidak menambahkan user ke grup `docker` kecuali opsi khusus digunakan.

Hal tersebut sengaja dipisahkan karena termasuk konfigurasi infrastruktur atau task hardening UKK.

## Opsi Penting

```text
--server-ip IP          IP binding Ubuntu Server
--internal-port PORT    Default 8080
--vuln-port PORT        Default 8081
--timezone TZ           Default Asia/Jakarta
--install-dir PATH      Lokasi instalasi permanen
--skip-docker-install   Jangan install Docker otomatis
--skip-systemd          Jangan membuat service systemd
--add-user-to-docker    Tambahkan user ke grup docker (hak setara root)
--force-rebuild         Build image tanpa cache
--non-interactive       Tanpa pertanyaan konfirmasi
```

## Pemeriksaan Setelah Setup

```bash
cd /opt/ukk-cyber-docker-lab
sudo ./scripts/labctl.sh status
sudo ./scripts/labctl.sh health
```

Buka dari PC Admin:

```text
http://192.168.50.10:8080
http://192.168.50.10:8081
```

## Pengelolaan Lab

```bash
sudo ./scripts/labctl.sh start
sudo ./scripts/labctl.sh stop
sudo ./scripts/labctl.sh restart
sudo ./scripts/labctl.sh status
sudo ./scripts/labctl.sh health
sudo ./scripts/labctl.sh logs
sudo ./scripts/labctl.sh logs-internal
sudo ./scripts/labctl.sh logs-vuln
sudo ./scripts/labctl.sh build
sudo ./scripts/labctl.sh reset
```

## Service Systemd

```bash
sudo systemctl status ukk-cyber-lab.service
sudo systemctl restart ukk-cyber-lab.service
sudo systemctl disable ukk-cyber-lab.service
```

Container juga menggunakan `restart: unless-stopped`, tetapi service systemd memudahkan administrasi stack sebagai satu unit.

## Setelah Reboot

```bash
sudo systemctl status docker
sudo systemctl status ukk-cyber-lab.service
sudo /opt/ukk-cyber-docker-lab/scripts/labctl.sh health
```

## Jika Script Menemukan Paket Konflik

Script berhenti jika menemukan paket Docker/container runtime yang berpotensi konflik. Ini dilakukan agar instalasi tidak menghapus atau merusak container lama secara otomatis.

Periksa paket:

```bash
dpkg -l | grep -E 'docker|containerd|runc|podman'
```

Tentukan secara manual apakah server masih memiliki data/container lain yang harus dipertahankan sebelum menghapus paket apa pun.

## MikroTik

Web Internal tidak boleh dibuat DNAT ke WAN.

Web Vulnerable saja yang diteruskan:

```text
10.10.10.100:8081 -> 192.168.50.10:8081
```

## Reset Sebelum Peserta Berikutnya

```bash
sudo /opt/ukk-cyber-docker-lab/scripts/labctl.sh reset
```

Reset menghapus volume database Web Vulnerable dan log latihan, kemudian membangun kondisi awal kembali.
