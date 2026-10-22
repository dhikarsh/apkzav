<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Harga jual = harga modal supplier + markup level (Rupiah, tanpa desimal).
        Schema::create('levels', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->unsignedInteger('markup')->default(0);
            $table->boolean('is_default')->default(false);
            $table->timestamps();
        });

        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->string('sku')->unique(); // buyer_sku_code Digiflazz
            $table->string('name');
            $table->string('category');
            $table->string('brand');
            $table->string('type')->nullable();
            $table->boolean('is_postpaid')->default(false);
            $table->unsignedBigInteger('cost')->default(0); // harga modal supplier
            $table->unsignedInteger('admin_fee')->default(0); // pascabayar
            $table->unsignedInteger('markup')->nullable(); // override markup level
            $table->boolean('supplier_active')->default(true);
            $table->boolean('is_active')->default(true);
            $table->text('description')->nullable();
            $table->timestamps();
            $table->index(['category', 'brand']);
        });

        Schema::create('transactions', function (Blueprint $table) {
            $table->id();
            $table->string('ref_id')->unique();
            $table->foreignId('user_id')->constrained();
            $table->foreignId('product_id')->constrained();
            $table->string('customer_no', 50);
            $table->string('kind', 12)->default('prepaid'); // prepaid | postpaid
            $table->string('status', 10)->default('pending'); // pending | success | failed
            $table->unsignedBigInteger('price'); // dibayar member
            $table->unsignedBigInteger('cost')->nullable(); // dibayar ke supplier
            $table->string('sn')->nullable();
            $table->string('rc', 10)->nullable();
            $table->string('message')->nullable();
            $table->json('detail')->nullable(); // data tagihan pascabayar
            $table->json('supplier_response')->nullable();
            $table->unsignedSmallInteger('check_count')->default(0);
            $table->timestamp('finished_at')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'created_at']);
            $table->index('status');
        });

        // Tagihan yang sudah dicek (inquiry) dan menunggu dibayar.
        Schema::create('bill_inquiries', function (Blueprint $table) {
            $table->id();
            $table->string('ref_id')->unique();
            $table->foreignId('user_id')->constrained();
            $table->foreignId('product_id')->constrained();
            $table->string('customer_no', 50);
            $table->string('customer_name')->nullable();
            $table->unsignedBigInteger('cost');
            $table->unsignedBigInteger('price');
            $table->json('detail')->nullable();
            $table->timestamp('expires_at');
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();
        });

        // Mutasi saldo: setiap perubahan saldo tercatat di sini.
        Schema::create('ledger_entries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained();
            $table->bigInteger('amount'); // + kredit, - debit
            $table->unsignedBigInteger('balance_after');
            $table->string('type', 20); // purchase | refund | deposit | transfer_in | transfer_out | adjustment
            $table->nullableMorphs('reference');
            $table->string('description');
            $table->timestamps();
            $table->index(['user_id', 'created_at']);
        });

        Schema::create('deposits', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained();
            $table->unsignedBigInteger('amount'); // nominal diminta
            $table->unsignedSmallInteger('unique_code')->default(0);
            $table->string('method', 30)->default('bank_transfer');
            $table->string('status', 10)->default('pending'); // pending | paid | rejected | expired
            $table->string('gateway_ref')->nullable();
            $table->string('note')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('deposits');
        Schema::dropIfExists('ledger_entries');
        Schema::dropIfExists('bill_inquiries');
        Schema::dropIfExists('transactions');
        Schema::dropIfExists('products');
        Schema::dropIfExists('levels');
    }
};
