<?php

namespace App\Services;

use App\Models\Deposit;
use Illuminate\Support\Facades\DB;

class DepositService
{
    public function __construct(private readonly LedgerService $ledger) {}

    /** Tandai deposit lunas dan tambahkan saldo (nominal + kode unik). Aman dipanggil dua kali. */
    public function approve(Deposit $deposit): Deposit
    {
        return DB::transaction(function () use ($deposit) {
            $deposit = Deposit::whereKey($deposit->id)->lockForUpdate()->firstOrFail();
            if ($deposit->status !== 'pending') {
                return $deposit;
            }

            $deposit->update(['status' => 'paid', 'paid_at' => now()]);
            $this->ledger->credit($deposit->user, $deposit->total, 'deposit', "Deposit #{$deposit->id}", $deposit);

            return $deposit;
        });
    }

    public function reject(Deposit $deposit, ?string $note = null): Deposit
    {
        return DB::transaction(function () use ($deposit, $note) {
            $deposit = Deposit::whereKey($deposit->id)->lockForUpdate()->firstOrFail();
            if ($deposit->status === 'pending') {
                $deposit->update(['status' => 'rejected', 'note' => $note]);
            }

            return $deposit;
        });
    }
}
