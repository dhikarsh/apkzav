<?php

namespace App\Http\Resources;

use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Transaction */
class TransactionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'ref_id' => $this->ref_id,
            'kind' => $this->kind,
            'status' => $this->status,
            'product' => [
                'sku' => $this->product->sku,
                'name' => $this->product->name,
                'brand' => $this->product->brand,
                'category' => $this->product->category,
            ],
            'customer_no' => $this->customer_no,
            'price' => $this->price,
            'sn' => $this->sn,
            'message' => $this->message,
            'detail' => $this->detail,
            'created_at' => $this->created_at,
            'finished_at' => $this->finished_at,
        ];
    }
}
