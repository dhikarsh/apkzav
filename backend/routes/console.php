<?php

use App\Jobs\ProcessTransaction;
use App\Models\Transaction;
use App\Services\ProductSyncService;
use App\Suppliers\Supplier;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('ppob:sync-products', function (ProductSyncService $sync) {
    $result = $sync->sync();
    $this->info("Produk baru: {$result['created']}, diperbarui: {$result['updated']}, dinonaktifkan: {$result['disabled']}");
})->purpose('Sinkron daftar harga dari supplier');

Artisan::command('ppob:check-pending', function () {
    // Cek ulang transaksi yang masih pending lebih dari 1 menit (cadangan bila webhook tidak masuk).
    $ids = Transaction::where('status', Transaction::PENDING)
        ->where('updated_at', '<', now()->subMinute())
        ->where('check_count', '<', 100)
        ->pluck('id');

    $ids->each(fn ($id) => ProcessTransaction::dispatch($id));
    $this->info("Dicek ulang: {$ids->count()}");
})->purpose('Cek ulang status transaksi pending');

Artisan::command('ppob:supplier-balance', function (Supplier $supplier) {
    $this->info('Saldo supplier: Rp '.number_format($supplier->balance(), 0, ',', '.'));
})->purpose('Tampilkan saldo deposit di supplier');

Schedule::command('ppob:check-pending')->everyMinute()->withoutOverlapping();
Schedule::command('ppob:sync-products')->hourly()->withoutOverlapping();
