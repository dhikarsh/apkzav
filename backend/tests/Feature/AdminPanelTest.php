<?php

namespace Tests\Feature;

use App\Models\Deposit;
use App\Models\Level;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class AdminPanelTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_pages_render(): void
    {
        Http::fake(['api.digiflazz.com/*' => Http::response(['data' => ['deposit' => 1000000]])]);
        Level::create(['name' => 'Member', 'markup' => 1000, 'is_default' => true]);
        $member = User::factory()->create();
        $product = Product::create(['sku' => 'x5', 'name' => 'XL 5K', 'category' => 'Pulsa', 'brand' => 'XL', 'cost' => 5100]);
        Transaction::create(['ref_id' => 'T1', 'user_id' => $member->id, 'product_id' => $product->id,
            'customer_no' => '0878', 'price' => 6100, 'cost' => 5100, 'status' => 'success']);
        Deposit::create(['user_id' => $member->id, 'amount' => 50000, 'unique_code' => 123]);

        $this->actingAs(User::factory()->admin()->create());

        foreach (['/admin', '/admin/transactions', '/admin/products', "/admin/products/{$product->id}/edit",
            '/admin/deposits', '/admin/users', '/admin/users/create', '/admin/levels'] as $url) {
            $this->get($url)->assertOk();
        }
    }

    public function test_member_cannot_open_admin_panel(): void
    {
        $this->actingAs(User::factory()->create());

        $this->get('/admin')->assertForbidden();
    }
}
