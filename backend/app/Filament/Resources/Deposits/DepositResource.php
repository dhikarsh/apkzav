<?php

namespace App\Filament\Resources\Deposits;

use App\Filament\Resources\Deposits\Pages\ListDeposits;
use App\Filament\Resources\Deposits\Tables\DepositsTable;
use App\Models\Deposit;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

class DepositResource extends Resource
{
    protected static ?string $model = Deposit::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedBanknotes;

    protected static ?string $modelLabel = 'deposit';

    protected static ?string $pluralModelLabel = 'Deposit';

    public static function getNavigationBadge(): ?string
    {
        $pending = Deposit::where('status', 'pending')->count();

        return $pending ? (string) $pending : null;
    }

    public static function table(Table $table): Table
    {
        return DepositsTable::configure($table);
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function getPages(): array
    {
        return [
            'index' => ListDeposits::route('/'),
        ];
    }
}
