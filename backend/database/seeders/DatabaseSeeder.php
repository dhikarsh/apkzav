<?php

namespace Database\Seeders;

use App\Models\Level;
use App\Models\User;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        Level::firstOrCreate(['name' => 'Member'], ['markup' => 1500, 'is_default' => true]);
        Level::firstOrCreate(['name' => 'Reseller'], ['markup' => 750]);
        Level::firstOrCreate(['name' => 'Agen'], ['markup' => 300]);

        // Admin contoh hanya untuk pengembangan; di server buat admin dengan `php artisan ppob:make-admin`.
        if (! app()->environment('local')) {
            return;
        }

        User::firstOrCreate(['phone' => '080000000000'], [
            'name' => 'Admin',
            'email' => 'admin@example.com',
            'password' => 'ubah-password-ini',
            'pin' => '000000',
            'role' => 'admin',
        ]);
    }
}
