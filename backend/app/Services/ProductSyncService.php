<?php

namespace App\Services;

use App\Models\Product;
use App\Suppliers\Supplier;

class ProductSyncService
{
    public function __construct(private readonly Supplier $supplier) {}

    /**
     * Tarik daftar harga supplier dan perbarui tabel produk.
     * Produk yang hilang dari supplier ditandai tidak aktif; nama, markup, dan status aktif dari admin tidak ditimpa.
     *
     * @return array{created:int, updated:int, disabled:int}
     */
    public function sync(): array
    {
        $items = [...$this->supplier->priceList(false), ...$this->supplier->priceList(true)];
        $seen = [];
        $created = $updated = 0;

        foreach ($items as $item) {
            $seen[] = $item['sku'];
            $product = Product::firstOrNew(['sku' => $item['sku']]);
            $isNew = ! $product->exists;

            if ($isNew) {
                $product->fill([
                    'name' => $item['name'],
                    'category' => $item['category'],
                    'brand' => $item['brand'],
                    'description' => $item['description'],
                ]);
            }

            $product->fill([
                'type' => $item['type'],
                'is_postpaid' => $item['is_postpaid'],
                'cost' => $item['cost'],
                'admin_fee' => $item['admin_fee'],
                'supplier_active' => $item['active'],
            ])->save();

            $isNew ? $created++ : $updated++;
        }

        $disabled = Product::whereNotIn('sku', $seen)->where('supplier_active', true)->update(['supplier_active' => false]);

        return compact('created', 'updated', 'disabled');
    }
}
