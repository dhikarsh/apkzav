<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Deposit extends Model
{
    protected $fillable = ['user_id', 'amount', 'unique_code', 'method', 'status', 'gateway_ref', 'note', 'paid_at'];

    protected function casts(): array
    {
        return ['amount' => 'integer', 'unique_code' => 'integer', 'paid_at' => 'datetime'];
    }

    /** Nominal yang harus ditransfer member (nominal + kode unik). */
    public function getTotalAttribute(): int
    {
        return $this->amount + $this->unique_code;
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
