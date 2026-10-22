<?php

namespace Tests\Feature;

use App\Models\BillInquiry;
use App\Models\Deposit;
use App\Models\Level;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use App\Services\DepositService;
use App\Services\LedgerService;
use App\Services\ProductSyncService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PpobTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    private Product $pulsa;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'services.digiflazz.username' => 'tester',
            'services.digiflazz.api_key' => 'key',
            'services.digiflazz.webhook_secret' => 'rahasia',
        ]);

        Level::create(['name' => 'Member', 'markup' => 1500, 'is_default' => true]);
        $this->user = User::factory()->create(['level_id' => Level::first()->id]);
        app(LedgerService::class)->credit($this->user, 50000, 'adjustment', 'Saldo awal');
        $this->pulsa = Product::create([
            'sku' => 'xld10', 'name' => 'XL 10.000', 'category' => 'Pulsa', 'brand' => 'XL', 'cost' => 10100,
        ]);
        Sanctum::actingAs($this->user);
    }

    private function fakeDigiflazz(array $data): void
    {
        Http::fake(['api.digiflazz.com/*' => Http::response(['data' => $data])]);
    }

    private function buy(): TestResponse
    {
        return $this->postJson('/api/v1/transactions', ['sku' => 'xld10', 'customer_no' => '087800001234', 'pin' => '123456']);
    }

    public function test_purchase_success_debits_balance_and_stores_sn(): void
    {
        $this->fakeDigiflazz(['status' => 'Sukses', 'sn' => 'SN123', 'rc' => '00', 'price' => 10100, 'message' => 'Transaksi Sukses']);

        $ref = $this->buy()->assertCreated()->json('data.ref_id');

        $trx = Transaction::where('ref_id', $ref)->first();
        $this->assertSame('success', $trx->status);
        $this->assertSame('SN123', $trx->sn);
        $this->assertSame(11600, $trx->price);
        $this->assertSame(50000 - 11600, $this->user->fresh()->balance);

        Http::assertSent(fn ($req) => $req['sign'] === md5('tester'.'key'.$ref) && $req['buyer_sku_code'] === 'xld10');
    }

    public function test_failed_purchase_is_refunded(): void
    {
        $this->fakeDigiflazz(['status' => 'Gagal', 'rc' => '40', 'message' => 'Nomor tujuan salah']);

        $this->buy()->assertCreated();

        $this->assertSame('failed', Transaction::first()->status);
        $this->assertSame(50000, $this->user->fresh()->balance);
        $this->assertSame(['adjustment', 'purchase', 'refund'], $this->user->ledgerEntries()->orderBy('id')->pluck('type')->all());
    }

    public function test_timeout_keeps_transaction_pending_without_refund(): void
    {
        Http::fake(fn () => throw new ConnectionException('timeout'));

        $this->buy()->assertCreated();

        $this->assertSame('pending', Transaction::first()->status);
        $this->assertSame(50000 - 11600, $this->user->fresh()->balance);
    }

    public function test_webhook_finalizes_pending_transaction_once(): void
    {
        $this->fakeDigiflazz(['status' => 'Pending', 'rc' => '03']);
        $ref = $this->buy()->json('data.ref_id');

        $body = json_encode(['data' => ['ref_id' => $ref, 'status' => 'Gagal', 'rc' => '40', 'message' => 'Gagal']]);
        $send = fn (string $sig) => $this->call('POST', '/api/v1/webhooks/digiflazz', [], [], [], [
            'CONTENT_TYPE' => 'application/json', 'HTTP_X_HUB_SIGNATURE' => $sig,
        ], $body);

        $send('sha1=salah')->assertUnauthorized();
        $send('sha1='.hash_hmac('sha1', $body, 'rahasia'))->assertOk();
        $send('sha1='.hash_hmac('sha1', $body, 'rahasia'))->assertOk(); // kiriman ganda tidak refund dua kali

        $this->assertSame('failed', Transaction::first()->status);
        $this->assertSame(50000, $this->user->fresh()->balance);
    }

    public function test_insufficient_balance_is_rejected(): void
    {
        $this->pulsa->update(['cost' => 100000]);
        Http::fake();

        $this->buy()->assertStatus(422)->assertJson(['message' => 'Saldo tidak cukup']);

        $this->assertSame(0, Transaction::count());
        Http::assertNothingSent();
    }

    public function test_wrong_pin_is_rejected(): void
    {
        $this->postJson('/api/v1/transactions', ['sku' => 'xld10', 'customer_no' => '0878', 'pin' => '999999'])
            ->assertStatus(422)->assertJsonValidationErrors('pin');
    }

    public function test_postpaid_inquiry_and_pay(): void
    {
        Product::create(['sku' => 'pln', 'name' => 'PLN Pascabayar', 'category' => 'Pascabayar', 'brand' => 'PLN', 'is_postpaid' => true]);
        $this->fakeDigiflazz(['status' => 'Sukses', 'rc' => '00', 'price' => 20000, 'admin' => 2500, 'customer_name' => 'BUDI']);

        $bill = $this->postJson('/api/v1/bills/inquiry', ['sku' => 'pln', 'customer_no' => '5300001'])
            ->assertOk()->assertJson(['customer_name' => 'BUDI', 'price' => 21500])->json();

        $this->postJson("/api/v1/bills/{$bill['ref_id']}/pay", ['pin' => '123456'])->assertCreated();
        $this->postJson("/api/v1/bills/{$bill['ref_id']}/pay", ['pin' => '123456'])
            ->assertStatus(422)->assertJson(['message' => 'Tagihan sudah dibayar']);

        $this->assertSame('success', Transaction::where('ref_id', $bill['ref_id'])->value('status'));
        $this->assertSame(50000 - 21500, $this->user->fresh()->balance);
        Http::assertSent(fn ($req) => ($req['commands'] ?? null) === 'pay-pasca');
    }

    public function test_expired_bill_cannot_be_paid(): void
    {
        $product = Product::create(['sku' => 'pln', 'name' => 'PLN', 'category' => 'Pascabayar', 'brand' => 'PLN', 'is_postpaid' => true]);
        BillInquiry::create([
            'ref_id' => 'INQ1', 'user_id' => $this->user->id, 'product_id' => $product->id, 'customer_no' => '1',
            'cost' => 1000, 'price' => 2000, 'expires_at' => now()->subMinute(),
        ]);

        $this->postJson('/api/v1/bills/INQ1/pay', ['pin' => '123456'])->assertStatus(422);
        $this->assertSame(50000, $this->user->fresh()->balance);
    }

    public function test_products_show_price_with_level_markup(): void
    {
        $this->getJson('/api/v1/products?category=Pulsa')
            ->assertOk()->assertJsonPath('0.sku', 'xld10')->assertJsonPath('0.price', 11600);
    }

    public function test_product_sync_updates_cost_and_disables_missing(): void
    {
        Product::create(['sku' => 'old', 'name' => 'Lama', 'category' => 'Pulsa', 'brand' => 'X', 'cost' => 1]);
        Http::fake(fn ($req) => Http::response(['data' => $req['cmd'] === 'prepaid' ? [
            ['buyer_sku_code' => 'xld10', 'product_name' => 'XL 10K', 'category' => 'Pulsa', 'brand' => 'XL', 'price' => 10200,
                'buyer_product_status' => true, 'seller_product_status' => true, 'unlimited_stock' => true, 'stock' => 0],
            ['buyer_sku_code' => 'tsel5', 'product_name' => 'Telkomsel 5K', 'category' => 'Pulsa', 'brand' => 'TELKOMSEL', 'price' => 5300,
                'buyer_product_status' => true, 'seller_product_status' => false, 'unlimited_stock' => true, 'stock' => 0],
        ] : []]));

        $result = app(ProductSyncService::class)->sync();

        $this->assertSame(['created' => 1, 'updated' => 1, 'disabled' => 1], $result);
        $this->assertSame(10200, $this->pulsa->fresh()->cost);
        $this->assertSame('XL 10.000', $this->pulsa->fresh()->name); // nama dari admin tidak ditimpa
        $this->assertFalse(Product::where('sku', 'tsel5')->first()->supplier_active);
        $this->assertFalse(Product::where('sku', 'old')->first()->supplier_active);
    }

    public function test_deposit_ticket_and_approval_credits_once(): void
    {
        $id = $this->postJson('/api/v1/deposits', ['amount' => 100000])->assertCreated()->json('id');
        $deposit = Deposit::find($id);

        app(DepositService::class)->approve($deposit);
        app(DepositService::class)->approve($deposit);

        $this->assertSame(50000 + $deposit->total, $this->user->fresh()->balance);
    }

    public function test_login_with_pin(): void
    {
        $this->postJson('/api/v1/auth/login', ['phone' => $this->user->phone, 'pin' => '000000', 'device_name' => 'hp'])
            ->assertStatus(422);
        $this->postJson('/api/v1/auth/login', ['phone' => $this->user->phone, 'pin' => '123456', 'device_name' => 'hp'])
            ->assertOk()->assertJsonStructure(['token', 'user' => ['balance']]);
    }
}
