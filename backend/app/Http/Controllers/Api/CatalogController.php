<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\Request;

class CatalogController extends Controller
{
    /** Kategori dan brand yang punya produk aktif, untuk menu utama aplikasi. */
    public function categories()
    {
        return Product::available()
            ->select('category', 'brand', 'is_postpaid')
            ->distinct()
            ->orderBy('category')
            ->orderBy('brand')
            ->get()
            ->groupBy('category')
            ->map(fn ($rows, $category) => [
                'category' => $category,
                'is_postpaid' => (bool) $rows->first()->is_postpaid,
                'brands' => $rows->pluck('brand')->unique()->values(),
            ])
            ->values();
    }

    public function products(Request $request)
    {
        $request->validate([
            'category' => ['nullable', 'string'],
            'brand' => ['nullable', 'string'],
        ]);
        $user = $request->user();

        return Product::available()
            ->when($request->category, fn ($q, $v) => $q->where('category', $v))
            ->when($request->brand, fn ($q, $v) => $q->where('brand', $v))
            ->orderBy('cost')
            ->get()
            ->map(fn (Product $p) => [
                'sku' => $p->sku,
                'name' => $p->name,
                'category' => $p->category,
                'brand' => $p->brand,
                'type' => $p->type,
                'is_postpaid' => $p->is_postpaid,
                // Pascabayar: harga final baru diketahui setelah cek tagihan.
                'price' => $p->is_postpaid ? null : $p->priceFor($user),
                'description' => $p->description,
            ]);
    }
}
