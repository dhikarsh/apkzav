<?php

namespace Tests\Feature;

use App\Models\Level;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use App\Services\LedgerService;
use App\Suppliers\OtomaxSupplier;
use App\Suppliers\Supplier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OtomaxTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'services.supplier' => 'otomax',
            'services.otomax.base_url' => 'http://10.244.165.1:5859',
            'services.otomax.member_id' => 'ZPP001',
            'services.otomax.pin' => '1234',
            'services.otomax.password' => 'abcd',
            'services.otomax.report_token' => 'token-rahasia',
        ]);
        $this->app->forgetInstance(Supplier::class);

        Level::create(['name' => 'Member', 'markup' => 1500, 'is_default' => true]);
        $this->user = User::factory()->create(['level_id' => Level::first()->id]);
        app(LedgerService::class)->credit($this->user, 50000, 'adjustment', 'Saldo awal');
        Product::create(['sku' => 'S10', 'name' => 'Telkomsel 10.000', 'category' => 'Pulsa', 'brand' => 'TELKOMSEL', 'cost' => 10100]);
        Sanctum::actingAs($this->user);
    }

    private function buy(): TestResponse
    {
        return $this->postJson('/api/v1/transactions', ['sku' => 'S10', 'customer_no' => '081200001234', 'pin' => '123456']);
    }

    public function test_purchase_sends_ip_center_request_with_sign(): void
    {
        Http::fake(['10.244.165.1:5859/*' => Http::response('R#1 S10.081200001234 SUKSES. SN: 0412345678901234. Hrg: 10.050. Saldo 990.000')]);

        $ref = $this->buy()->assertCreated()->json('data.ref_id');

        $trx = Transaction::where('ref_id', $ref)->first();
        $this->assertSame('success', $trx->status);
        $this->assertSame('0412345678901234', $trx->sn);
        $this->assertSame(10050, $trx->cost);

        $sign = rtrim(strtr(base64_encode(sha1("OtomaX|ZPP001|S10|081200001234|{$ref}|1234|abcd", true)), '+/', '-_'), '=');
        Http::assertSent(fn ($req) => str_starts_with($req->url(), 'http://10.244.165.1:5859/trx?')
            && $req['product'] === 'S10' && $req['dest'] === '081200001234' && $req['refID'] === $ref
            && $req['memberID'] === 'ZPP001' && $req['sign'] === $sign && ! isset($req['pin']));
    }

    public function test_failed_reply_is_refunded(): void
    {
        Http::fake(['10.244.165.1:5859/*' => Http::response('S10.081200001234 GAGAL. Nomor tujuan salah')]);

        $this->buy()->assertCreated();

        $this->assertSame('failed', Transaction::first()->status);
        $this->assertSame(50000, $this->user->fresh()->balance);
    }

    public function test_vpn_down_keeps_transaction_pending(): void
    {
        Http::fake(fn () => throw new ConnectionException('timeout'));

        $this->buy()->assertCreated();

        $this->assertSame('pending', Transaction::first()->status);
        $this->assertSame(50000 - 11600, $this->user->fresh()->balance);
    }

    public function test_report_finalizes_pending_transaction(): void
    {
        Http::fake(['10.244.165.1:5859/*' => Http::response('R#1 S10.081200001234 akan diproses')]);
        $ref = $this->buy()->json('data.ref_id');
        $this->assertSame('pending', Transaction::first()->status);

        $this->get('/api/v1/webhooks/otomax/salah?refid='.$ref.'&message=SUKSES')->assertUnauthorized();

        $message = urlencode("S10.081200001234 SUKSES SN: ABC123 ref {$ref}");
        $this->get("/api/v1/webhooks/otomax/token-rahasia?message={$message}")->assertOk();

        $trx = Transaction::first();
        $this->assertSame('success', $trx->status);
        $this->assertSame('ABC123', $trx->sn);
    }

    public function test_parse_message_reads_failure_before_pending(): void
    {
        $this->assertSame('pending', OtomaxSupplier::parseMessage('Transaksi sedang diproses')->status);
        $this->assertSame('failed', OtomaxSupplier::parseMessage('Maaf, produk tidak tersedia')->status);
        $this->assertSame('PELANGGAN A', OtomaxSupplier::parseMessage('CEK PLN 1234 SUKSES Nama: PELANGGAN A, Tagihan: Rp 125.500,00')->customerName);
        $this->assertSame(125500, OtomaxSupplier::parseMessage('SUKSES Nama: X, Tagihan: Rp 125.500,00')->cost);
    }
}
