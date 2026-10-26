<?php

use App\Jobs\ProcessTransaction;
use App\Models\Transaction;
use App\Models\User;
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

Artisan::command('ppob:make-admin {email} {--password=} {--phone=080000000000} {--name=Admin}', function (string $email) {
    $password = $this->option('password') ?: $this->secret('Password admin');
    if (strlen((string) $password) < 8) {
        $this->error('Password minimal 8 karakter.');

        return 1;
    }

    $user = User::where('email', $email)->first() ?? User::firstOrNew(['phone' => $this->option('phone')]);
    $user->fill(['name' => $user->name ?: $this->option('name'), 'email' => $email, 'password' => $password]);
    $user->role = 'admin';
    $user->is_active = true;
    $user->pin ??= (string) random_int(100000, 999999);
    $user->save();

    $this->info("Admin siap: {$email}");
})->purpose('Buat atau perbarui akun admin panel');

Schedule::command('ppob:check-pending')->everyMinute()->withoutOverlapping();
// OtomaX tidak punya daftar harga lewat IP Center; produknya diisi manual di panel admin.
Schedule::command('ppob:sync-products')->hourly()->withoutOverlapping()
    ->when(fn () => config('services.supplier') !== 'otomax');
