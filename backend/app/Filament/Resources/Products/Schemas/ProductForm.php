<?php

namespace App\Filament\Resources\Products\Schemas;

use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Schema;

class ProductForm
{
    public static function configure(Schema $schema): Schema
    {
        // SKU, harga modal, dan status supplier diisi oleh sinkronisasi; admin hanya mengatur tampilan & markup.
        return $schema
            ->components([
                TextInput::make('sku')->label('SKU supplier')->disabled(),
                TextInput::make('cost')->label('Harga modal')->prefix('Rp')->disabled(),
                TextInput::make('name')->label('Nama')->required(),
                TextInput::make('category')->label('Kategori')->required(),
                TextInput::make('brand')->label('Brand')->required(),
                TextInput::make('markup')
                    ->label('Markup khusus produk')
                    ->helperText('Kosongkan untuk memakai markup level member.')
                    ->numeric()
                    ->minValue(0)
                    ->prefix('Rp'),
                Toggle::make('is_active')->label('Dijual'),
                Toggle::make('supplier_active')->label('Aktif di supplier')->disabled(),
                Textarea::make('description')->label('Keterangan')->columnSpanFull(),
            ]);
    }
}
