<?php

namespace App\Filament\Resources\Users\Schemas;

use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Schema;

class UserForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('name')->label('Nama')->required(),
                TextInput::make('phone')->label('No. HP (login)')->tel()->required()->unique(ignoreRecord: true),
                TextInput::make('pin')
                    ->label('PIN (6 angka)')
                    ->password()
                    ->rule('digits:6')
                    ->required(fn (string $operation) => $operation === 'create')
                    ->dehydrated(fn (?string $state) => filled($state))
                    ->helperText('Kosongkan bila tidak diubah.'),
                Select::make('level_id')->label('Level harga')->relationship('level', 'name'),
                Select::make('upline_id')->label('Upline')->relationship('upline', 'name')->searchable(),
                Select::make('role')->options(['member' => 'Member', 'admin' => 'Admin'])->default('member')->required(),
                TextInput::make('email')->label('Email (login panel admin)')->email()->unique(ignoreRecord: true),
                TextInput::make('password')
                    ->label('Password panel admin')
                    ->password()
                    ->dehydrated(fn (?string $state) => filled($state)),
                Toggle::make('is_active')->label('Aktif')->default(true),
            ]);
    }
}
