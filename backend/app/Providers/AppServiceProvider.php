<?php

namespace App\Providers;

use App\Suppliers\DigiflazzSupplier;
use App\Suppliers\OtomaxSupplier;
use App\Suppliers\Supplier;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // Pilih supplier lewat SUPPLIER di .env tanpa mengubah kode transaksi.
        $this->app->singleton(Supplier::class, fn () => match (config('services.supplier')) {
            'otomax' => new OtomaxSupplier(
                baseUrl: (string) config('services.otomax.base_url'),
                memberId: (string) config('services.otomax.member_id'),
                pin: (string) config('services.otomax.pin'),
                password: (string) config('services.otomax.password'),
                options: config('services.otomax.patterns') + config('services.otomax'),
            ),
            default => new DigiflazzSupplier(
                username: (string) config('services.digiflazz.username'),
                apiKey: (string) config('services.digiflazz.api_key'),
                testing: (bool) config('services.digiflazz.testing'),
            ),
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
