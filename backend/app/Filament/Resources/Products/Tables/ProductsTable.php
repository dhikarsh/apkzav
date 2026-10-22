<?php

namespace App\Filament\Resources\Products\Tables;

use App\Models\Product;
use Filament\Actions\BulkAction;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\ToggleColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Collection;

class ProductsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('sku')->label('SKU')->searchable(),
                TextColumn::make('name')->label('Nama')->searchable(),
                TextColumn::make('category')->label('Kategori')->sortable(),
                TextColumn::make('brand')->sortable(),
                TextColumn::make('cost')->label('Modal')->money('IDR')->sortable(),
                TextColumn::make('markup')->label('Markup khusus')->money('IDR')->placeholder('level'),
                IconColumn::make('is_postpaid')->label('Pasca')->boolean(),
                IconColumn::make('supplier_active')->label('Supplier')->boolean(),
                ToggleColumn::make('is_active')->label('Dijual'),
            ])
            ->defaultSort('category')
            ->filters([
                SelectFilter::make('category')->label('Kategori')
                    ->options(fn () => Product::distinct()->orderBy('category')->pluck('category', 'category')->all()),
                SelectFilter::make('brand')
                    ->options(fn () => Product::distinct()->orderBy('brand')->pluck('brand', 'brand')->all()),
                TernaryFilter::make('supplier_active')->label('Aktif di supplier'),
            ])
            ->recordActions([
                EditAction::make(),
            ])
            ->toolbarActions([
                BulkAction::make('enable')->label('Jual')
                    ->action(fn (Collection $records) => $records->each->update(['is_active' => true])),
                BulkAction::make('disable')->label('Jangan jual')
                    ->action(fn (Collection $records) => $records->each->update(['is_active' => false])),
            ]);
    }
}
