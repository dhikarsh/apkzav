<?php

namespace App\Filament\Resources\Levels\Schemas;

use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Schema;

class LevelForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('name')
                    ->label('Nama')
                    ->required(),
                TextInput::make('markup')
                    ->label('Markup per transaksi')
                    ->prefix('Rp')
                    ->required()
                    ->numeric()
                    ->default(0),
                Toggle::make('is_default')
                    ->label('Default untuk member baru')
                    ->required(),
            ]);
    }
}
