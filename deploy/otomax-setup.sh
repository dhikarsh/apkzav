#!/usr/bin/env bash
# Sambungkan backend ZPP Reload ke OtomaX kantor lewat OpenVPN (MikroTik), lalu pakai OtomaX sebagai supplier.
# Jalankan di VPS SETELAH deploy/install.sh selesai:
#
#   1. Upload file .ovpn khusus VPS ke server, mis. /root/kantor.ovpn (jangan taruh di repo).
#   2. sudo bash /var/www/zpp/deploy/otomax-setup.sh /root/kantor.ovpn
#
# Nilai bisa diberikan lewat variabel lingkungan agar tanpa pertanyaan:
# VPN_USER, VPN_PASS, OTOMAX_URL, OTOMAX_MEMBER_ID, OTOMAX_PIN, OTOMAX_PASSWORD.
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/zpp}"
BACKEND="$APP_DIR/backend"
OVPN="${1:-}"
VPN_NAME=kantor
VPN_DIR=/etc/openvpn/client

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }
ask() {
  local var=$1 prompt=$2 secret=${3:-}
  if [[ -n "${!var:-}" ]]; then return; fi
  if [[ -n "$secret" ]]; then read -rsp "$prompt: " "${var?}"; echo; else read -rp "$prompt: " "${var?}"; fi
}
setenv() {
  local key=$1 value=$2
  if grep -q "^#\? *$key=" .env; then
    KEY="$key" VALUE="$value" perl -pi -e 's/^#? *\Q$ENV{KEY}\E=.*/$ENV{KEY}=$ENV{VALUE}/' .env
  else
    printf '%s=%s\n' "$key" "$value" >>.env
  fi
}

[[ $EUID -eq 0 ]] || die "Jalankan sebagai root (sudo bash otomax-setup.sh /root/kantor.ovpn)."
[[ -f "$BACKEND/.env" ]] || die "Backend belum terpasang. Jalankan deploy/install.sh dulu."
[[ -n "$OVPN" && -f "$OVPN" ]] || die "Sebutkan file .ovpn, contoh: sudo bash otomax-setup.sh /root/kantor.ovpn"

ask VPN_USER "Username VPN (PPP secret di MikroTik)"
ask VPN_PASS "Password VPN" secret
OTOMAX_URL="${OTOMAX_URL:-http://10.244.165.1:5859}"
ask OTOMAX_MEMBER_ID "Kode reseller ZPP di OtomaX (mis. ZPP001)"
ask OTOMAX_PIN "PIN reseller itu" secret
ask OTOMAX_PASSWORD "Password H2H reseller itu" secret

log "Memasang OpenVPN client"
export DEBIAN_FRONTEND=noninteractive
apt-get install -y openvpn
install -d -m 700 "$VPN_DIR"
printf '%s\n%s\n' "$VPN_USER" "$VPN_PASS" >"$VPN_DIR/$VPN_NAME.auth"
chmod 600 "$VPN_DIR/$VPN_NAME.auth"
{
  # Baris auth-user-pass diarahkan ke file kredensial agar bisa jalan otomatis.
  sed -e '/^auth-user-pass/d' "$OVPN"
  cat <<CONF

auth-user-pass $VPN_DIR/$VPN_NAME.auth
# MikroTik tidak mendukung negosiasi cipher OpenVPN 2.6; pakai cipher dari profil.
data-ciphers AES-256-CBC:AES-128-CBC:AES-256-GCM
data-ciphers-fallback AES-256-CBC
# Hanya lalu lintas ke jaringan kantor yang lewat VPN; internet VPS tetap langsung.
pull-filter ignore redirect-gateway
CONF
} >"$VPN_DIR/$VPN_NAME.conf"
chmod 600 "$VPN_DIR/$VPN_NAME.conf"
systemctl enable --now "openvpn-client@$VPN_NAME"
systemctl restart "openvpn-client@$VPN_NAME"

log "Menunggu VPN tersambung ke OtomaX ($OTOMAX_URL)"
ok=
for _ in $(seq 1 20); do
  if curl -s -o /dev/null -m 5 "$OTOMAX_URL/"; then ok=1; break; fi
  sleep 3
done
if [[ -z "$ok" ]]; then
  echo "OtomaX belum terjangkau. Cek: journalctl -u openvpn-client@$VPN_NAME -n 50"
  echo "Pastikan IP Center aktif di OtomaX dan PC OtomaX tersambung ke VPN. Pengaturan tetap disimpan."
fi

log "Mengaktifkan OtomaX sebagai supplier"
cd "$BACKEND"
REPORT_TOKEN=$(grep '^OTOMAX_REPORT_TOKEN=' .env | cut -d= -f2- || true)
[[ -n "$REPORT_TOKEN" ]] || REPORT_TOKEN=$(head -c 1024 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 32)
setenv SUPPLIER otomax
setenv OTOMAX_URL "$OTOMAX_URL"
setenv OTOMAX_MEMBER_ID "$OTOMAX_MEMBER_ID"
setenv OTOMAX_PIN "$OTOMAX_PIN"
setenv OTOMAX_PASSWORD "$OTOMAX_PASSWORD"
setenv OTOMAX_REPORT_TOKEN "$REPORT_TOKEN"
php artisan optimize
supervisorctl restart 'zpp-worker:*'

APP_URL=$(grep '^APP_URL=' .env | cut -d= -f2-)
cat <<DONE

============================================================
 Backend ZPP sekarang bertransaksi lewat OtomaX.

 Isi di OtomaX, pada reseller $OTOMAX_MEMBER_ID (tipe IP / H2H):
   URL report : $APP_URL/api/v1/webhooks/otomax/$REPORT_TOKEN

 Produk diisi manual di panel admin ($APP_URL/admin):
   SKU = kode produk di OtomaX (mis. S10), harga modal = harga reseller ZPP di OtomaX.

 Status VPN : systemctl status openvpn-client@$VPN_NAME
============================================================
DONE
