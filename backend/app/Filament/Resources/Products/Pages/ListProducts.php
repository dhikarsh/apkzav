<?php

namespace App\Filament\Resources\Products\Pages;

use App\Filament\Resources\Products\ProductResource;
use App\Services\ProductSyncService;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ListRecords;
use Throwable;

class ListProducts extends ListRecords
{
    protected static string $resource = ProductResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Action::make('sync')
                ->label('Sinkron harga supplier')
                ->requiresConfirmation()
                ->action(function (ProductSyncService $sync) {
                    try {
                        $r = $sync->sync();
                        Notification::make()->success()
                            ->title("Baru {$r['created']}, diperbarui {$r['updated']}, nonaktif {$r['disabled']}")
                            ->send();
                    } catch (Throwable $e) {
                        Notification::make()->danger()->title('Sinkron gagal')->body($e->getMessage())->send();
                    }
                }),
        ];
    }
}
