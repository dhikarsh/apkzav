<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class Product extends Model
{
    protected $fillable = [
        'sku', 'name', 'category', 'brand', 'type', 'is_postpaid', 'cost', 'admin_fee',
        'markup', 'supplier_active', 'is_active', 'description',
    ];

    protected function casts(): array
    {
        return [
            'is_postpaid' => 'boolean',
            'cost' => 'integer',
            'admin_fee' => 'integer',
            'markup' => 'integer',
            'supplier_active' => 'boolean',
            'is_active' => 'boolean',
        ];
    }

    public function scopeAvailable(Builder $query): Builder
    {
        return $query->where('is_active', true)->where('supplier_active', true);
    }

    /** Markup yang berlaku untuk user: override produk, lalu level user, lalu level default. */
    public function markupFor(User $user): int
    {
        if ($this->markup !== null) {
            return $this->markup;
        }

        return ($user->level ?? Level::default())?->markup ?? 0;
    }

    /** Harga jual prabayar untuk user. */
    public function priceFor(User $user): int
    {
        return $this->cost + $this->markupFor($user);
    }
}
