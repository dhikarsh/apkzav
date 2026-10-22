<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Transaction extends Model
{
    public const PENDING = 'pending';

    public const SUCCESS = 'success';

    public const FAILED = 'failed';

    protected $fillable = [
        'ref_id', 'user_id', 'product_id', 'customer_no', 'kind', 'status', 'price', 'cost',
        'sn', 'rc', 'message', 'detail', 'supplier_response', 'check_count', 'finished_at',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'integer',
            'cost' => 'integer',
            'detail' => 'array',
            'supplier_response' => 'array',
            'finished_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function isFinal(): bool
    {
        return $this->status !== self::PENDING;
    }
}
