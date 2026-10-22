<?php

namespace App\Filament\Resources\Users\Tables;

use App\Models\User;
use App\Services\InsufficientBalanceException;
use App\Services\LedgerService;
use Filament\Actions\Action;
use Filament\Actions\EditAction;
use Filament\Forms\Components\TextInput;
use Filament\Notifications\Notification;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class UsersTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')->label('Nama')->searchable(),
                TextColumn::make('phone')->label('HP')->searchable(),
                TextColumn::make('level.name')->label('Level'),
                TextColumn::make('upline.name')->label('Upline'),
                TextColumn::make('balance')->label('Saldo')->money('IDR')->sortable(),
                IconColumn::make('is_active')->label('Aktif')->boolean(),
                TextColumn::make('role')->badge(),
                TextColumn::make('created_at')->label('Daftar')->dateTime('d/m/y')->sortable(),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('level_id')->label('Level')->relationship('level', 'name'),
                SelectFilter::make('role')->options(['member' => 'Member', 'admin' => 'Admin']),
            ])
            ->recordActions([
                EditAction::make(),
                Action::make('adjust')
                    ->label('Ubah saldo')
                    ->icon('heroicon-o-scale')
                    ->schema([
                        TextInput::make('amount')->label('Jumlah (pakai minus untuk mengurangi)')->integer()->required()->notIn([0]),
                        TextInput::make('description')->label('Keterangan')->required(),
                    ])
                    ->action(function (User $record, array $data, LedgerService $ledger) {
                        $amount = (int) $data['amount'];
                        try {
                            $amount > 0
                                ? $ledger->credit($record, $amount, 'adjustment', $data['description'])
                                : $ledger->debit($record, -$amount, 'adjustment', $data['description']);
                            Notification::make()->success()->title('Saldo diperbarui')->send();
                        } catch (InsufficientBalanceException) {
                            Notification::make()->danger()->title('Saldo member tidak cukup')->send();
                        }
                    }),
            ]);
    }
}
