#!/usr/bin/env bash
# Perbarui backend ZPP Reload ke versi terbaru di repo. Jalankan sebagai root: sudo bash update.sh
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/zpp}"
BRANCH="${BRANCH:-main}"
cd "$APP_DIR"

git fetch origin "$BRANCH"
git reset --hard "origin/$BRANCH"

cd backend
php artisan down --retry=15 || true
composer install --no-dev --optimize-autoloader --no-interaction
php artisan migrate --force
php artisan optimize
chown -R www-data:www-data storage bootstrap/cache
php artisan up
supervisorctl restart 'zpp-worker:*'

echo "Selesai. Versi: $(git -C "$APP_DIR" log --oneline -1)"
