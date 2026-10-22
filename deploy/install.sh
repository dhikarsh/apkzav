#!/usr/bin/env bash
# Pasang backend ZPP Reload di VPS Ubuntu 22.04/24.04 yang masih baru.
#
# Jalankan sebagai root:
#   curl -fsSL https://raw.githubusercontent.com/dhikarsh/apkzav/main/deploy/install.sh -o install.sh
#   sudo bash install.sh
#
# Skrip menanyakan domain, email admin, dan kredensial Digiflazz. Nilai yang sama bisa diberikan
# lewat variabel lingkungan (DOMAIN, ADMIN_EMAIL, DIGIFLAZZ_USERNAME, DIGIFLAZZ_API_KEY,
# DEPOSIT_BANK_INFO, GITHUB_TOKEN) agar berjalan tanpa pertanyaan.
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/dhikarsh/apkzav.git}"
BRANCH="${BRANCH:-main}"
APP_DIR="${APP_DIR:-/var/www/zpp}"
BACKEND="$APP_DIR/backend"
PHP_VERSION=8.3
DB_NAME=zpp
DB_USER=zpp

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }
ask() {
  # ask VAR "Pertanyaan" [rahasia]
  local var=$1 prompt=$2 secret=${3:-}
  if [[ -n "${!var:-}" ]]; then return; fi
  if [[ -n "$secret" ]]; then read -rsp "$prompt: " "${var?}"; echo; else read -rp "$prompt: " "${var?}"; fi
}
randstr() {
  # Baca jumlah byte tetap agar tidak ada pipa yang terputus (pipefail).
  local s
  s=$(head -c 1024 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9')
  printf '%s' "${s:0:${1:-32}}"
}

[[ $EUID -eq 0 ]] || die "Jalankan sebagai root (sudo bash install.sh)."
. /etc/os-release
[[ "$ID" == ubuntu ]] || die "Skrip ini untuk Ubuntu 22.04 atau 24.04."

ask DOMAIN "Domain API (contoh: api.zppreload.id)"
ask ADMIN_EMAIL "Email admin (untuk login panel & sertifikat HTTPS)"
ask DIGIFLAZZ_USERNAME "Username Digiflazz"
ask DIGIFLAZZ_API_KEY "API key Digiflazz (production)" secret
ask DEPOSIT_BANK_INFO "Rekening deposit (contoh: BCA 1234567890 a.n. ZPP Reload)"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-$(randstr 14)}"

log "Memasang paket sistem"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y software-properties-common ca-certificates curl git unzip
if ! apt-cache show "php$PHP_VERSION-fpm" >/dev/null 2>&1; then
  add-apt-repository -y ppa:ondrej/php
  apt-get update -y
fi
apt-get install -y nginx mariadb-server redis-server supervisor certbot python3-certbot-nginx ufw \
  "php$PHP_VERSION-fpm" "php$PHP_VERSION-cli" "php$PHP_VERSION-mysql" "php$PHP_VERSION-mbstring" \
  "php$PHP_VERSION-xml" "php$PHP_VERSION-curl" "php$PHP_VERSION-zip" "php$PHP_VERSION-bcmath" \
  "php$PHP_VERSION-intl" "php$PHP_VERSION-gd" "php$PHP_VERSION-redis" "php$PHP_VERSION-sqlite3"
if ! command -v composer >/dev/null; then
  curl -fsSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
fi

log "Menyiapkan database"
if [[ -f "$BACKEND/.env" ]]; then
  DB_PASS=$(grep '^DB_PASSWORD=' "$BACKEND/.env" | cut -d= -f2-)
else
  DB_PASS=$(randstr 24)
fi
mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL

log "Mengambil kode aplikasi"
CLONE_URL=$REPO_URL
[[ -n "${GITHUB_TOKEN:-}" ]] && CLONE_URL="https://x-access-token:${GITHUB_TOKEN}@${REPO_URL#https://}"
if [[ -d "$APP_DIR/.git" ]]; then
  git -C "$APP_DIR" fetch origin "$BRANCH" && git -C "$APP_DIR" reset --hard "origin/$BRANCH"
else
  git clone --branch "$BRANCH" "$CLONE_URL" "$APP_DIR" \
    || die "Gagal mengambil repo. Jika repo privat, isi GITHUB_TOKEN (token baca-saja) lalu ulangi."
  git -C "$APP_DIR" remote set-url origin "$REPO_URL"
fi

log "Mengatur konfigurasi aplikasi"
cd "$BACKEND"
if [[ ! -f .env ]]; then
  cp .env.example .env
  WEBHOOK_SECRET=$(randstr 32)
else
  WEBHOOK_SECRET=$(grep '^DIGIFLAZZ_WEBHOOK_SECRET=' .env | cut -d= -f2-)
  [[ -n "$WEBHOOK_SECRET" ]] || WEBHOOK_SECRET=$(randstr 32)
fi
setenv() {
  # setenv KEY VALUE: ganti baris KEY=... atau tambahkan bila belum ada.
  local key=$1 value=$2
  if grep -q "^#\? *$key=" .env; then
    KEY="$key" VALUE="$value" perl -pi -e 's/^#? *\Q$ENV{KEY}\E=.*/$ENV{KEY}=$ENV{VALUE}/' .env
  else
    printf '%s=%s\n' "$key" "$value" >>.env
  fi
}
setenv APP_NAME '"ZPP Reload"'
setenv APP_ENV production
setenv APP_DEBUG false
setenv APP_URL "https://$DOMAIN"
setenv APP_LOCALE id
setenv APP_TIMEZONE Asia/Jakarta
setenv LOG_LEVEL warning
setenv DB_CONNECTION mariadb
setenv DB_HOST 127.0.0.1
setenv DB_PORT 3306
setenv DB_DATABASE "$DB_NAME"
setenv DB_USERNAME "$DB_USER"
setenv DB_PASSWORD "$DB_PASS"
setenv QUEUE_CONNECTION redis
setenv CACHE_STORE redis
setenv SESSION_DRIVER redis
setenv SESSION_SECURE_COOKIE true
setenv DIGIFLAZZ_USERNAME "$DIGIFLAZZ_USERNAME"
setenv DIGIFLAZZ_API_KEY "$DIGIFLAZZ_API_KEY"
setenv DIGIFLAZZ_WEBHOOK_SECRET "$WEBHOOK_SECRET"
setenv DIGIFLAZZ_TESTING false
setenv DEPOSIT_BANK_INFO "\"$DEPOSIT_BANK_INFO\""
chmod 640 .env

composer install --no-dev --optimize-autoloader --no-interaction
grep -q '^APP_KEY=base64' .env || php artisan key:generate --force
php artisan migrate --force
php artisan db:seed --force
php artisan ppob:make-admin "$ADMIN_EMAIL" --password="$ADMIN_PASSWORD"
php artisan storage:link 2>/dev/null || true
php artisan optimize
chown -R www-data:www-data "$BACKEND/storage" "$BACKEND/bootstrap/cache"
chgrp www-data .env

log "Mengatur nginx"
cat >/etc/nginx/sites-available/zpp <<NGINX
server {
    listen 80;
    server_name $DOMAIN;
    root $BACKEND/public;
    index index.php;
    client_max_body_size 10m;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php$PHP_VERSION-fpm.sock;
    }

    location ~ /\.(?!well-known) {
        deny all;
    }
}
NGINX
ln -sf /etc/nginx/sites-available/zpp /etc/nginx/sites-enabled/zpp
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

log "Mengatur antrean transaksi & jadwal"
cat >/etc/supervisor/conf.d/zpp-worker.conf <<CONF
[program:zpp-worker]
command=php $BACKEND/artisan queue:work redis --sleep=1 --tries=3 --timeout=90
process_name=%(program_name)s_%(process_num)02d
numprocs=2
user=www-data
autostart=true
autorestart=true
stopwaitsecs=100
redirect_stderr=true
stdout_logfile=$BACKEND/storage/logs/worker.log
CONF
supervisorctl reread
supervisorctl update
supervisorctl restart 'zpp-worker:*'
echo "* * * * * www-data cd $BACKEND && php artisan schedule:run >> /dev/null 2>&1" >/etc/cron.d/zpp-scheduler
chmod 644 /etc/cron.d/zpp-scheduler

log "Mengatur firewall"
ufw allow OpenSSH >/dev/null
ufw allow 'Nginx Full' >/dev/null
ufw --force enable >/dev/null

log "Memasang sertifikat HTTPS"
if ! certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$ADMIN_EMAIL" --redirect; then
  echo "Sertifikat belum terpasang. Pastikan DNS $DOMAIN sudah mengarah ke IP server ini,"
  echo "lalu jalankan: certbot --nginx -d $DOMAIN --redirect"
fi

log "Sinkron daftar produk dari Digiflazz"
sudo -u www-data php artisan ppob:sync-products \
  || echo "Sinkron gagal. Biasanya karena IP server belum di-whitelist di Digiflazz; ulangi nanti dari panel admin."

SERVER_IP=$(curl -fsS https://api.ipify.org || hostname -I | awk '{print $1}')
cat <<DONE

============================================================
 ZPP Reload sudah terpasang.

 Panel admin  : https://$DOMAIN/admin
 Email admin  : $ADMIN_EMAIL
 Password     : $ADMIN_PASSWORD   (simpan, lalu ganti setelah login)

 Isi di dashboard Digiflazz:
   Whitelist IP     : $SERVER_IP
   Webhook URL      : https://$DOMAIN/api/v1/webhooks/digiflazz
   Webhook secret   : $WEBHOOK_SECRET

 Alamat untuk aplikasi (API_URL): https://$DOMAIN
============================================================
DONE
