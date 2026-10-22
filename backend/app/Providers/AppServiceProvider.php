<?php

namespace App\Providers;

use App\Suppliers\DigiflazzSupplier;
use App\Suppliers\Supplier;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // Ganti supplier di sini (mis. adapter OtomaX H2H) tanpa mengubah kode transaksi.
        $this->app->singleton(Supplier::class, fn () => new DigiflazzSupplier(
            username: (string) config('services.digiflazz.username'),
            apiKey: (string) config('services.digiflazz.api_key'),
            testing: (bool) config('services.digiflazz.testing'),
        ));
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
