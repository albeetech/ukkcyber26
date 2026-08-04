# Skenario Siswa - Web Security Assessment

Anda bertindak sebagai auditor keamanan yang memperoleh izin tertulis untuk memeriksa dua layanan pada Ubuntu Server.

## Scope

- Web Internal: `http://192.168.50.10:8080`
- Web Lab dari WAN: `http://10.10.10.100:8081`

## Tugas

1. Lakukan baseline audit Web Internal tanpa mengubah konfigurasi.
2. Temukan minimal dua kelemahan konfigurasi pada Web Internal.
3. Lakukan enumeration Web Lab menggunakan browser dan Burp Suite/OWASP ZAP.
4. Buktikan minimal dua celah pada Web Lab dengan dampak minimum.
5. Catat source IP, URL, method, status code, evidence, dampak, severity, dan rekomendasi.
6. Jangan menghapus data, melakukan denial of service, persistence, atau pengujian di luar scope.
