# ZPP Reload: Aplikasi Pulsa & PPOB

Pengganti aplikasi lama (template OtoReport). Semua kode dan data milik sendiri, supplier utama **Digiflazz**.

```
backend/   Laravel 12: API aplikasi, panel admin (Filament) di /admin, koneksi Digiflazz
mobile/    Flutter: aplikasi Android untuk member/agen
```

## Fitur versi pertama

- Daftar & login dengan nomor HP + PIN 6 angka, PIN diminta lagi di setiap transaksi.
- Beli produk prabayar (pulsa, paket data, token PLN, e-money, game, voucher) dari daftar harga Digiflazz.
- Cek & bayar tagihan pascabayar (PLN, BPJS, PDAM, internet, dll).
- Saldo member dengan mutasi lengkap; saldo dipotong di awal dan otomatis dikembalikan bila transaksi gagal.
- Tiket deposit transfer bank dengan kode unik, dikonfirmasi admin.
- Riwayat transaksi, status diperbarui otomatis (webhook Digiflazz + cek ulang tiap menit).
- Struk: cetak ke printer thermal Bluetooth 58mm atau bagikan sebagai teks.
- Panel admin: dashboard omzet/laba/saldo Digiflazz, transaksi, produk & markup, level harga, member (ubah saldo), konfirmasi deposit.

## Menjalankan backend

Butuh PHP 8.2+, Composer, database (MySQL/PostgreSQL; SQLite cukup untuk coba-coba) dan Redis (disarankan untuk antrian).

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
# isi DB_*, DIGIFLAZZ_*, DEPOSIT_BANK_INFO di .env
php artisan migrate --seed
php artisan ppob:sync-products      # tarik daftar harga Digiflazz
php artisan serve                   # API di http://localhost:8000/api/v1, admin di /admin
php artisan queue:work              # wajib jalan: memproses transaksi ke supplier
php artisan schedule:work           # cek ulang transaksi pending & sinkron harga tiap jam
```

Login admin awal (dari seeder): `admin@example.com` / `ubah-password-ini`. **Ganti segera** di menu Member.

Di server produksi jalankan `queue:work` dengan Supervisor dan tambahkan cron `* * * * * php artisan schedule:run`.

### Pengaturan Digiflazz

1. Di dashboard Digiflazz, menu Atur Koneksi > API: ambil **Username** dan **API Key** (Development Key untuk uji coba, Production Key untuk live).
2. Daftarkan IP server Anda di whitelist IP Digiflazz.
3. Atur webhook ke `https://domain-anda/api/v1/webhooks/digiflazz` dan salin **secret**-nya ke `DIGIFLAZZ_WEBHOOK_SECRET`.
4. Selama uji coba biarkan `DIGIFLAZZ_TESTING=true`. Ubah ke `false` saat live.

### Harga jual

Harga jual = harga modal Digiflazz + markup. Markup diatur per **level harga** (Member, Reseller, Agen) dan bisa ditimpa per produk. Sinkronisasi harga tidak menimpa nama, markup, atau status "Dijual" yang sudah diatur admin.

### Tes

```bash
cd backend && php artisan test
```

## Pasang di server (VPS)

Butuh VPS Ubuntu 22.04/24.04 (minimal 2 GB RAM) dengan IP tetap, dan subdomain (mis. `api.zppreload.com`) yang record A-nya sudah mengarah ke IP VPS.

```bash
curl -fsSL https://raw.githubusercontent.com/dhikarsh/apkzav/main/deploy/install.sh -o install.sh
sudo bash install.sh
```

Skrip memasang nginx, PHP 8.3, MariaDB, Redis, worker antrean (supervisor), jadwal per menit (cron), firewall, dan HTTPS (Let's Encrypt), lalu membuat akun admin. Di akhir ia menampilkan password admin, IP untuk whitelist Digiflazz, serta URL dan secret webhook. Untuk versi baru: `sudo bash /var/www/zpp/deploy/update.sh`.

### Pakai OtomaX sendiri sebagai supplier

Backend bisa bertransaksi ke OtomaX milik sendiri lewat modul **IP Center** (H2H HTTP), dengan VPS tersambung ke VPN kantor:

1. Di OtomaX: aktifkan modul IP Center, lalu buat satu reseller khusus ZPP (mis. `ZPP001`) dengan akses IP/H2H.
2. Di MikroTik: buat user VPN (PPP secret) khusus VPS, lalu ekspor profil `.ovpn`-nya. Jangan simpan file ini di repo.
3. Upload `.ovpn` ke VPS, lalu jalankan `sudo bash /var/www/zpp/deploy/otomax-setup.sh /root/kantor.ovpn`.
4. Isi **URL report** yang ditampilkan skrip ke data reseller ZPP di OtomaX.
5. Isi produk di panel admin: SKU = kode produk OtomaX, harga modal = harga reseller ZPP di OtomaX. Daftar harga tidak disinkron otomatis.

Request yang dikirim: `GET {OTOMAX_URL}/trx?product=&qty=1&dest=&refID=&memberID=&sign=`, dengan
`sign = base64url(SHA1("OtomaX|memberID|product|dest|refID|pin|password"))`. Balasan OtomaX berupa teks; kata
"SUKSES"/"GAGAL", SN, dan harga dibaca dengan pola yang bisa diubah lewat `OTOMAX_*_PATTERN` di `.env`.
Untuk pascabayar, kode produk cek/bayar diatur lewat `OTOMAX_INQUIRY_PRODUCT` dan `OTOMAX_PAY_PRODUCT` (default `CEK{sku}` dan `BYR{sku}`).

## Aplikasi Android

Butuh Flutter stable terbaru (dibuat dengan 3.47) dan Android SDK.

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8000          # emulator ke backend lokal
flutter build apk --release --dart-define=API_URL=https://api.domain-anda.com
```

Tanpa `API_URL` (dikosongkan), aplikasi berjalan dalam **mode demo**: server tiruan di dalam aplikasi dengan data contoh, saldo Rp 1.000.000, PIN 123456, deposit otomatis terkonfirmasi setelah 10 detik, dan nomor tujuan berakhiran `0000` sengaja gagal untuk mencoba refund. Begitu variabel repo `API_URL` diisi, build berikutnya otomatis tersambung ke server.

Build rilis wajib memakai `https`. GitHub Actions (`.github/workflows/ci.yml`) otomatis menjalankan tes dan membuat APK; unduh dari tab Actions > run terbaru > Artifacts. Isi variabel repo `API_URL` dengan alamat backend Anda.

Sebelum rilis ke Play Store: buat keystore untuk tanda tangan rilis, dan sesuaikan `applicationId` di `mobile/android/app/build.gradle.kts`.

## Arah pengembangan berikutnya

- Tahap 2: downline & komisi, transfer saldo, transaksi massal & terjadwal, nomor favorit, notifikasi push/WA, deposit otomatis lewat payment gateway (VA/QRIS).
- Tahap 3: poin & hadiah, verifikasi KYC, tiket komplain, NFC e-money, iOS.
- Supplier lain (mis. OtomaX H2H) cukup menambah kelas baru yang mengimplementasikan `App\Suppliers\Supplier`.
