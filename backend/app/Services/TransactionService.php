<?php

namespace App\Services;

use App\Jobs\ProcessTransaction;
use App\Models\BillInquiry;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use App\Suppliers\Supplier;
use App\Suppliers\SupplierResult;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

class TransactionService
{
    public function __construct(
        private readonly Supplier $supplier,
        private readonly LedgerService $ledger,
    ) {}

    /** Buat transaksi prabayar: potong saldo, lalu kirim ke supplier lewat antrian. */
    public function purchase(User $user, Product $product, string $customerNo): Transaction
    {
        if ($product->is_postpaid || ! $product->is_active || ! $product->supplier_active) {
            throw new TransactionException('Produk sedang tidak tersedia');
        }

        $price = $product->priceFor($user);

        $trx = DB::transaction(function () use ($user, $product, $customerNo, $price) {
            $trx = Transaction::create([
                'ref_id' => self::newRefId(),
                'user_id' => $user->id,
                'product_id' => $product->id,
                'customer_no' => $customerNo,
                'kind' => 'prepaid',
                'status' => Transaction::PENDING,
                'price' => $price,
                'cost' => $product->cost,
            ]);

            $this->ledger->debit($user, $price, 'purchase', "{$product->name} {$customerNo}", $trx);

            return $trx;
        });

        ProcessTransaction::dispatch($trx->id)->afterCommit();

        return $trx;
    }

    /** Cek tagihan pascabayar. Tidak memotong saldo. */
    public function inquiry(User $user, Product $product, string $customerNo): BillInquiry
    {
        if (! $product->is_postpaid || ! $product->is_active || ! $product->supplier_active) {
            throw new TransactionException('Produk sedang tidak tersedia');
        }

        $refId = self::newRefId('INQ');
        $result = $this->supplier->inquiry($product->sku, $customerNo, $refId);

        if ($result->status !== 'success' || $result->cost === null) {
            throw new TransactionException($result->message ?: 'Cek tagihan gagal');
        }

        return BillInquiry::create([
            'ref_id' => $refId,
            'user_id' => $user->id,
            'product_id' => $product->id,
            'customer_no' => $customerNo,
            'customer_name' => $result->customerName,
            'cost' => $result->cost,
            'price' => $result->cost + $product->markupFor($user),
            'detail' => $result->detail,
            'expires_at' => now()->addMinutes(config('services.ppob.inquiry_ttl_minutes')),
        ]);
    }

    /** Bayar tagihan hasil inquiry. */
    public function payBill(User $user, BillInquiry $inquiry): Transaction
    {
        $trx = DB::transaction(function () use ($user, $inquiry) {
            $inquiry = BillInquiry::whereKey($inquiry->id)->lockForUpdate()->firstOrFail();

            if ($inquiry->user_id !== $user->id) {
                throw new TransactionException('Tagihan tidak ditemukan');
            }
            if ($inquiry->paid_at !== null) {
                throw new TransactionException('Tagihan sudah dibayar');
            }
            if ($inquiry->expires_at->isPast()) {
                throw new TransactionException('Data tagihan kedaluwarsa, silakan cek ulang');
            }

            $inquiry->update(['paid_at' => now()]);

            // ref_id pembayaran harus sama dengan ref_id inquiry (aturan Digiflazz).
            $trx = Transaction::create([
                'ref_id' => $inquiry->ref_id,
                'user_id' => $user->id,
                'product_id' => $inquiry->product_id,
                'customer_no' => $inquiry->customer_no,
                'kind' => 'postpaid',
                'status' => Transaction::PENDING,
                'price' => $inquiry->price,
                'cost' => $inquiry->cost,
                'detail' => ['customer_name' => $inquiry->customer_name] + ($inquiry->detail ?? []),
            ]);

            $this->ledger->debit($user, $inquiry->price, 'purchase', "Bayar {$inquiry->product->name} {$inquiry->customer_no}", $trx);

            return $trx;
        });

        ProcessTransaction::dispatch($trx->id)->afterCommit();

        return $trx;
    }

    /** Kirim (atau cek ulang) transaksi ke supplier. Aman dipanggil berulang. */
    public function process(Transaction $trx): Transaction
    {
        if ($trx->isFinal()) {
            return $trx;
        }

        $sku = $trx->product->sku;
        $firstAttempt = $trx->check_count === 0;

        try {
            $result = match (true) {
                $trx->kind === 'prepaid' => $this->supplier->purchase($sku, $trx->customer_no, $trx->ref_id),
                $firstAttempt => $this->supplier->pay($sku, $trx->customer_no, $trx->ref_id),
                default => $this->supplier->postpaidStatus($sku, $trx->customer_no, $trx->ref_id),
            };
        } catch (Throwable $e) {
            // Status di supplier tidak diketahui: biarkan pending, jangan refund.
            Log::error('Supplier error', ['ref_id' => $trx->ref_id, 'error' => $e->getMessage()]);
            $result = new SupplierResult(status: 'pending', message: 'Menunggu respon supplier');
        }

        return $this->applyResult($trx, $result);
    }

    /** Terapkan status dari supplier (respon API atau webhook). Status final tidak bisa berubah lagi. */
    public function applyResult(Transaction $trx, SupplierResult $result): Transaction
    {
        return DB::transaction(function () use ($trx, $result) {
            $trx = Transaction::whereKey($trx->id)->lockForUpdate()->firstOrFail();
            if ($trx->isFinal()) {
                return $trx;
            }

            $trx->fill([
                'rc' => $result->rc ?? $trx->rc,
                'message' => $result->message ?? $trx->message,
                'supplier_response' => $result->raw ?: $trx->supplier_response,
                'check_count' => $trx->check_count + 1,
            ]);

            if ($result->status === 'success') {
                $trx->fill([
                    'status' => Transaction::SUCCESS,
                    'sn' => $result->sn,
                    'cost' => $result->cost ?? $trx->cost,
                    'finished_at' => now(),
                ]);
            } elseif ($result->status === 'failed') {
                $trx->fill(['status' => Transaction::FAILED, 'finished_at' => now()]);
                $this->ledger->credit($trx->user, $trx->price, 'refund', "Refund {$trx->ref_id}", $trx);
            }

            $trx->save();

            return $trx;
        });
    }

    public static function newRefId(string $prefix = 'TRX'): string
    {
        return $prefix.now()->format('ymdHis').Str::upper(Str::random(6));
    }
}
