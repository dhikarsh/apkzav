<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class BillInquiry extends Model
{
    protected $fillable = [
        'ref_id', 'user_id', 'product_id', 'customer_no', 'customer_name', 'cost', 'price',
        'detail', 'expires_at', 'paid_at',
    ];

    protected function casts(): array
    {
        return [
            'cost' => 'integer',
            'price' => 'integer',
            'detail' => 'array',
            'expires_at' => 'datetime',
            'paid_at' => 'datetime',
        ];
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
