<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Deposit;
use Illuminate\Http\Request;

class BalanceController extends Controller
{
    /** Mutasi saldo member. */
    public function mutations(Request $request)
    {
        return $request->user()->ledgerEntries()
            ->latest('id')
            ->paginate(30, ['id', 'amount', 'balance_after', 'type', 'description', 'created_at']);
    }

    public function deposits(Request $request)
    {
        return $request->user()->deposits()->latest('id')->paginate(20)
            ->through(fn (Deposit $d) => $this->depositJson($d));
    }

    /** Tiket deposit: member transfer sejumlah nominal + kode unik, admin mengonfirmasi di panel. */
    public function createDeposit(Request $request)
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:'.config('services.ppob.deposit_min'), 'max:100000000'],
        ]);

        $pending = $request->user()->deposits()->where('status', 'pending')->count();
        if ($pending >= 3) {
            return response()->json(['message' => 'Masih ada 3 tiket deposit yang belum dibayar'], 422);
        }

        $deposit = $request->user()->deposits()->create([
            'amount' => $data['amount'],
            'unique_code' => random_int(100, 999),
            'method' => 'bank_transfer',
        ]);

        return response()->json($this->depositJson($deposit), 201);
    }

    private function depositJson(Deposit $d): array
    {
        return [
            'id' => $d->id,
            'amount' => $d->amount,
            'unique_code' => $d->unique_code,
            'total' => $d->total,
            'status' => $d->status,
            'bank_info' => config('services.ppob.deposit_bank_info'),
            'created_at' => $d->created_at,
            'paid_at' => $d->paid_at,
        ];
    }
}
