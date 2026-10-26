<?php

namespace App\Filament\Widgets;

use App\Models\Deposit;
use App\Models\Transaction;
use App\Suppliers\Supplier;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Throwable;

class TodayStats extends StatsOverviewWidget
{
    protected ?string $pollingInterval = '30s';

    protected function getStats(): array
    {
        $today = Transaction::whereDate('created_at', today());
        $success = (clone $today)->where('status', Transaction::SUCCESS);
        $rp = fn (int $v) => 'Rp '.number_format($v, 0, ',', '.');

        try {
            $supplierBalance = $rp(app(Supplier::class)->balance());
        } catch (Throwable) {
            $supplierBalance = 'tidak terbaca';
        }

        return [
            Stat::make('Transaksi sukses hari ini', $success->count())
                ->description((clone $today)->where('status', Transaction::PENDING)->count().' pending, '
                    .(clone $today)->where('status', Transaction::FAILED)->count().' gagal'),
            Stat::make('Omzet hari ini', $rp((int) $success->sum('price'))),
            Stat::make('Laba kotor hari ini', $rp((int) $success->get()->sum(fn ($t) => $t->price - $t->cost))),
            Stat::make('Saldo supplier', $supplierBalance)
                ->description(Deposit::where('status', 'pending')->count().' tiket deposit menunggu'),
        ];
    }
}
