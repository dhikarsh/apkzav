<?php

namespace App\Filament\Resources\Transactions\Tables;

use App\Jobs\ProcessTransaction;
use App\Models\Transaction;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class TransactionsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('created_at')->label('Waktu')->dateTime('d/m/y H:i:s')->sortable(),
                TextColumn::make('ref_id')->label('Ref ID')->searchable()->copyable(),
                TextColumn::make('user.name')->label('Member')->searchable(),
                TextColumn::make('product.name')->label('Produk'),
                TextColumn::make('customer_no')->label('Tujuan')->searchable(),
                TextColumn::make('price')->label('Harga')->money('IDR'),
                TextColumn::make('cost')->label('Modal')->money('IDR')->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('status')->badge()->color(fn (string $state) => match ($state) {
                    Transaction::SUCCESS => 'success',
                    Transaction::FAILED => 'danger',
                    default => 'warning',
                }),
                TextColumn::make('sn')->label('SN')->copyable()->limit(30),
                TextColumn::make('message')->label('Pesan')->limit(40)->toggleable(),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('status')->options([
                    Transaction::PENDING => 'Pending',
                    Transaction::SUCCESS => 'Sukses',
                    Transaction::FAILED => 'Gagal',
                ]),
            ])
            ->recordActions([
                Action::make('recheck')
                    ->label('Cek status')
                    ->visible(fn (Transaction $record) => ! $record->isFinal())
                    ->action(function (Transaction $record) {
                        ProcessTransaction::dispatch($record->id);
                        Notification::make()->success()->title('Cek status dikirim ke antrian')->send();
                    }),
            ])
            ->poll('15s');
    }
}
