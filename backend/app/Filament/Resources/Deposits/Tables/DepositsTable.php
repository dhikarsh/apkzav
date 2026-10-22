<?php

namespace App\Filament\Resources\Deposits\Tables;

use App\Models\Deposit;
use App\Services\DepositService;
use Filament\Actions\Action;
use Filament\Forms\Components\TextInput;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class DepositsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('created_at')->label('Waktu')->dateTime('d/m/y H:i')->sortable(),
                TextColumn::make('user.name')->label('Member')->searchable(),
                TextColumn::make('user.phone')->label('HP')->searchable(),
                TextColumn::make('total')->label('Harus ditransfer')->money('IDR'),
                TextColumn::make('status')->badge()->color(fn (string $state) => match ($state) {
                    'paid' => 'success',
                    'rejected', 'expired' => 'danger',
                    default => 'warning',
                }),
                TextColumn::make('paid_at')->label('Dikonfirmasi')->dateTime('d/m/y H:i'),
                TextColumn::make('note')->label('Catatan')->limit(30),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('status')->options([
                    'pending' => 'Menunggu', 'paid' => 'Lunas', 'rejected' => 'Ditolak',
                ])->default('pending'),
            ])
            ->recordActions([
                Action::make('approve')
                    ->label('Konfirmasi')
                    ->color('success')
                    ->requiresConfirmation()
                    ->modalDescription(fn (Deposit $record) => 'Pastikan dana Rp '.number_format($record->total, 0, ',', '.').' sudah masuk ke rekening.')
                    ->visible(fn (Deposit $record) => $record->status === 'pending')
                    ->action(fn (Deposit $record, DepositService $service) => $service->approve($record)),
                Action::make('reject')
                    ->label('Tolak')
                    ->color('danger')
                    ->schema([TextInput::make('note')->label('Alasan')])
                    ->visible(fn (Deposit $record) => $record->status === 'pending')
                    ->action(fn (Deposit $record, array $data, DepositService $service) => $service->reject($record, $data['note'] ?? null)),
            ]);
    }
}
