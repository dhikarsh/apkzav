<?php

namespace App\Suppliers;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Klien API Digiflazz (https://developer.digiflazz.com).
 * Semua request POST JSON ke https://api.digiflazz.com/v1 dengan sign md5.
 */
class DigiflazzSupplier implements Supplier
{
    public function __construct(
        private readonly string $username,
        private readonly string $apiKey,
        private readonly bool $testing = false,
        private readonly string $baseUrl = 'https://api.digiflazz.com/v1',
    ) {}

    public function balance(): int
    {
        $data = $this->post('/cek-saldo', [
            'cmd' => 'deposit',
            'username' => $this->username,
            'sign' => $this->sign('depo'),
        ]);

        return (int) ($data['deposit'] ?? 0);
    }

    public function priceList(bool $postpaid = false): array
    {
        $data = $this->post('/price-list', [
            'cmd' => $postpaid ? 'pasca' : 'prepaid',
            'username' => $this->username,
            'sign' => $this->sign('pricelist'),
        ]);

        if (! array_is_list($data)) {
            throw new RuntimeException('Digiflazz price-list: '.($data['message'] ?? 'respon tidak dikenal'));
        }

        return array_map(fn (array $p) => [
            'sku' => $p['buyer_sku_code'],
            'name' => $p['product_name'],
            'category' => $p['category'] ?? 'Lainnya',
            'brand' => $p['brand'] ?? '-',
            'type' => $p['type'] ?? null,
            'cost' => (int) ($p['price'] ?? 0),
            'admin_fee' => (int) ($p['admin'] ?? 0),
            'active' => ($p['buyer_product_status'] ?? false) && ($p['seller_product_status'] ?? false)
                && ($postpaid || ($p['unlimited_stock'] ?? false) || ($p['stock'] ?? 0) > 0),
            'is_postpaid' => $postpaid,
            'description' => $p['desc'] ?? null,
        ], $data);
    }

    public function purchase(string $sku, string $customerNo, string $refId): SupplierResult
    {
        return $this->transact([
            'buyer_sku_code' => $sku,
            'customer_no' => $customerNo,
            'ref_id' => $refId,
        ]);
    }

    public function inquiry(string $sku, string $customerNo, string $refId): SupplierResult
    {
        return $this->transact([
            'commands' => 'inq-pasca',
            'buyer_sku_code' => $sku,
            'customer_no' => $customerNo,
            'ref_id' => $refId,
        ]);
    }

    public function pay(string $sku, string $customerNo, string $refId): SupplierResult
    {
        return $this->transact([
            'commands' => 'pay-pasca',
            'buyer_sku_code' => $sku,
            'customer_no' => $customerNo,
            'ref_id' => $refId,
        ]);
    }

    public function postpaidStatus(string $sku, string $customerNo, string $refId): SupplierResult
    {
        return $this->transact([
            'commands' => 'status-pasca',
            'buyer_sku_code' => $sku,
            'customer_no' => $customerNo,
            'ref_id' => $refId,
        ]);
    }

    /** Ubah payload transaksi Digiflazz (respon API atau webhook) ke SupplierResult. */
    public static function toResult(array $data): SupplierResult
    {
        $status = match (strtolower((string) ($data['status'] ?? ''))) {
            'sukses' => 'success',
            'gagal' => 'failed',
            default => 'pending',
        };

        return new SupplierResult(
            status: $status,
            sn: ($data['sn'] ?? '') !== '' ? (string) $data['sn'] : null,
            rc: isset($data['rc']) ? (string) $data['rc'] : null,
            message: $data['message'] ?? null,
            cost: isset($data['price']) ? (int) $data['price'] : null,
            raw: $data,
            customerName: $data['customer_name'] ?? null,
            detail: array_filter([
                'admin' => $data['admin'] ?? null,
                'selling_price' => $data['selling_price'] ?? null,
                'desc' => $data['desc'] ?? null,
            ], fn ($v) => $v !== null),
        );
    }

    private function transact(array $payload): SupplierResult
    {
        $payload = ['username' => $this->username] + $payload + [
            'sign' => $this->sign($payload['ref_id']),
        ];
        if ($this->testing) {
            $payload['testing'] = true;
        }

        try {
            $data = $this->post('/transaction', $payload);
        } catch (ConnectionException $e) {
            // Timeout: status belum pasti, jangan dianggap gagal. Akan dicek ulang.
            Log::warning('Digiflazz timeout', ['ref_id' => $payload['ref_id'], 'error' => $e->getMessage()]);

            return new SupplierResult(status: 'pending', message: 'Menunggu respon supplier');
        }

        return self::toResult($data);
    }

    private function post(string $path, array $payload): array
    {
        $response = $this->http()->post($this->baseUrl.$path, $payload);

        // Digiflazz mengirim detail error di body {data:{rc,message}} walau HTTP 4xx.
        $data = $response->json('data');
        if (! is_array($data)) {
            throw new RuntimeException("Digiflazz {$path}: HTTP {$response->status()}");
        }

        return $data;
    }

    private function http(): PendingRequest
    {
        return Http::acceptJson()->asJson()->timeout(30)->connectTimeout(10);
    }

    private function sign(string $suffix): string
    {
        return md5($this->username.$this->apiKey.$suffix);
    }
}
