<?php

namespace App\Suppliers;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Klien H2H ke modul "IP Center" OtomaX milik sendiri (biasanya lewat VPN kantor).
 *
 * Request: GET {base_url}/trx?product=&qty=&dest=&refID=&memberID=&sign=
 * sign = base64 url-safe dari SHA1 mentah atas "OtomaX|memberID|product|dest|refID|pin|password".
 * OtomaX membalas teks bebas; status, SN, dan harga dibaca dengan pola di config/services.php.
 * Mengirim ulang refID yang sama dibalas OtomaX dengan status transaksi itu (tidak diproses dua kali).
 */
class OtomaxSupplier implements Supplier
{
    public function __construct(
        private readonly string $baseUrl,
        private readonly string $memberId,
        private readonly string $pin,
        private readonly string $password,
        private readonly array $options = [],
    ) {}

    /** OtomaX IP Center tidak punya perintah cek saldo standar; saldo dilihat di OtomaX. */
    public function balance(): int
    {
        throw new RuntimeException('Saldo OtomaX dilihat langsung di aplikasi OtomaX.');
    }

    /** Harga tidak ditarik otomatis; produk diisi manual di panel admin dengan SKU = kode produk OtomaX. */
    public function priceList(bool $postpaid = false): array
    {
        throw new RuntimeException('OtomaX tidak menyediakan daftar harga lewat IP Center. Isi produk di panel admin.');
    }

    public function purchase(string $sku, string $customerNo, string $refId): SupplierResult
    {
        return $this->transact($sku, $customerNo, $refId);
    }

    public function inquiry(string $sku, string $customerNo, string $refId): SupplierResult
    {
        return $this->transact($this->productCode('inquiry_product', $sku), $customerNo, $refId.'I');
    }

    public function pay(string $sku, string $customerNo, string $refId): SupplierResult
    {
        return $this->transact($this->productCode('pay_product', $sku), $customerNo, $refId);
    }

    public function postpaidStatus(string $sku, string $customerNo, string $refId): SupplierResult
    {
        return $this->pay($sku, $customerNo, $refId);
    }

    public function sign(string $product, string $dest, string $refId): string
    {
        $plain = "OtomaX|{$this->memberId}|{$product}|{$dest}|{$refId}|{$this->pin}|{$this->password}";

        return rtrim(strtr(base64_encode(sha1($plain, true)), '+/', '-_'), '=');
    }

    /** Ubah pesan teks OtomaX (balasan langsung atau report) ke SupplierResult. */
    public static function parseMessage(string $message, array $options = []): SupplierResult
    {
        $o = $options + self::defaultPatterns();
        $text = trim($message);

        $status = match (true) {
            (bool) preg_match($o['success_pattern'], $text) => 'success',
            (bool) preg_match($o['failed_pattern'], $text) => 'failed',
            default => 'pending',
        };

        $match = fn (string $key) => preg_match($o[$key], $text, $m) ? trim($m[1]) : null;
        $price = $match('price_pattern');

        return new SupplierResult(
            status: $status,
            sn: $status === 'success' ? rtrim((string) $match('sn_pattern'), '.') ?: null : null,
            message: mb_substr($text, 0, 500),
            cost: $price !== null ? (int) preg_replace('/\D/', '', preg_replace('/,\d{2}$/', '', $price)) : null,
            raw: ['message' => $text],
            customerName: $match('name_pattern'),
        );
    }

    /** @return array<string,string> */
    public static function defaultPatterns(): array
    {
        return [
            'success_pattern' => '/\b(sukses|berhasil|success)\b/i',
            'failed_pattern' => '/\b(gagal|failed|dibatalkan|ditolak|salah|tidak\s+(?:dikenal|tersedia|valid|cukup|aktif|terdaftar)|maaf)\b/i',
            'sn_pattern' => '/\bSN\s*[:=]?\s*([^\s,;]+(?:\/[^\s,;]+)*)/i',
            'price_pattern' => '/\b(?:harga|hrg|price|total|tagihan)\s*[:=]?\s*(?:Rp\.?\s*)?([\d.,]+)/i',
            'name_pattern' => '/\b(?:nama|name)\s*[:=]\s*([^,;\n]+?)(?=\s*(?:[,;\n]|\b(?:tagihan|total|periode|admin)\b|$))/i',
        ];
    }

    private function transact(string $product, string $dest, string $refId): SupplierResult
    {
        $query = [
            'product' => $product,
            'qty' => 1,
            'dest' => $dest,
            'refID' => $refId,
            'memberID' => $this->memberId,
            'sign' => $this->sign($product, $dest, $refId),
        ];

        try {
            $response = Http::timeout((int) ($this->options['timeout'] ?? 30))
                ->connectTimeout(10)
                ->get(rtrim($this->baseUrl, '/').'/'.ltrim($this->options['path'] ?? 'trx', '/'), $query);
        } catch (ConnectionException $e) {
            // VPN putus / OtomaX lambat: status belum pasti, cek ulang nanti dengan refID yang sama.
            Log::warning('OtomaX tidak terjangkau', ['ref_id' => $refId, 'error' => $e->getMessage()]);

            return new SupplierResult(status: 'pending', message: 'Menunggu respon OtomaX');
        }

        if ($response->serverError()) {
            return new SupplierResult(status: 'pending', message: "OtomaX HTTP {$response->status()}");
        }

        return self::parseMessage($response->body(), $this->options);
    }

    private function productCode(string $key, string $sku): string
    {
        return str_replace('{sku}', $sku, (string) ($this->options[$key] ?? '{sku}'));
    }
}
