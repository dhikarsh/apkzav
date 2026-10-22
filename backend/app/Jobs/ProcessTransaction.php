<?php

namespace App\Jobs;

use App\Models\Transaction;
use App\Services\TransactionService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class ProcessTransaction implements ShouldQueue
{
    use Queueable;

    public int $tries = 1;

    public function __construct(public readonly int $transactionId) {}

    public function handle(TransactionService $service): void
    {
        $trx = Transaction::find($this->transactionId);
        if ($trx) {
            $service->process($trx);
        }
    }
}
