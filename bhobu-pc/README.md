# BHOBU RELOAD untuk PC (Windows)

Aplikasi desktop yang membuka web member `https://bhobureload.otoreport.com/` di jendela sendiri, dengan:

- bilah atas bergaya e-commerce: logo, kembali/maju/muat ulang/beranda, zoom, tombol CS WhatsApp;
- layar pembuka dan halaman "tidak bisa terhubung" yang rapi;
- **Tema Modern** (CSS di `src/theme.css`) yang bisa dinyalakan/dimatikan dari tombol "Tema";
- login tersimpan, satu jendela saja, link di luar OtoReport dibuka di browser biasa.

Transaksi tetap diproses oleh web OtoReport; aplikasi ini tidak menyimpan atau membaca PIN/password.

## Unduh

Setiap perubahan di folder ini dibuild otomatis oleh GitHub Actions (workflow **BHOBU RELOAD PC**).
Buka run terakhir, lalu unduh artifact `bhobu-reload-pc`:

- `BHOBU-RELOAD-Setup-x.y.z.exe`: installer (shortcut di desktop & Start Menu);
- `BHOBU-RELOAD-Portable-x.y.z.exe`: langsung jalan tanpa instal.

Windows SmartScreen bisa memberi peringatan karena aplikasi belum ditandatangani: klik "More info" > "Run anyway".

## Pintasan

F5 muat ulang · Alt+←/→ kembali/maju · Ctrl +/−/0 zoom · F12 alat pengembang (untuk menyesuaikan tema).

## Mengembangkan

```
npm ci
npm start      # jalankan
npm run dist   # buat installer Windows (di Windows)
```
