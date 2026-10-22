<?php

namespace App\Services;

use App\Models\LedgerEntry;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

/**
 * Satu-satunya pintu untuk mengubah saldo member.
 * Baris user dikunci (SELECT ... FOR UPDATE) agar dua transaksi bersamaan tidak membuat saldo minus.
 */
class LedgerService
{
    public function debit(User $user, int $amount, string $type, string $description, ?Model $reference = null): LedgerEntry
    {
        return $this->apply($user, -$amount, $type, $description, $reference);
    }

    public function credit(User $user, int $amount, string $type, string $description, ?Model $reference = null): LedgerEntry
    {
        return $this->apply($user, $amount, $type, $description, $reference);
    }

    private function apply(User $user, int $amount, string $type, string $description, ?Model $reference): LedgerEntry
    {
        return DB::transaction(function () use ($user, $amount, $type, $description, $reference) {
            $locked = User::whereKey($user->getKey())->lockForUpdate()->firstOrFail();

            $newBalance = $locked->balance + $amount;
            if ($newBalance < 0) {
                throw new InsufficientBalanceException($locked->balance, -$amount);
            }

            $locked->forceFill(['balance' => $newBalance])->save();
            $user->setAttribute('balance', $newBalance);

            return LedgerEntry::create([
                'user_id' => $locked->id,
                'amount' => $amount,
                'balance_after' => $newBalance,
                'type' => $type,
                'reference_type' => $reference?->getMorphClass(),
                'reference_id' => $reference?->getKey(),
                'description' => $description,
            ]);
        });
    }
}
