<?php

namespace App\Suppliers;

interface Supplier
{
    /** Saldo deposit kita di supplier. */
    public function balance(): int;

    /**
     * Daftar produk dari supplier.
     *
     * @return list<array{sku:string,name:string,category:string,brand:string,type:?string,cost:int,admin_fee:int,active:bool,is_postpaid:bool,description:?string}>
     */
    public function priceList(bool $postpaid = false): array;

    /** Beli produk prabayar. Mengulang dengan ref_id yang sama = cek status. */
    public function purchase(string $sku, string $customerNo, string $refId): SupplierResult;

    /** Cek tagihan pascabayar. */
    public function inquiry(string $sku, string $customerNo, string $refId): SupplierResult;

    /** Bayar tagihan yang sudah di-inquiry dengan ref_id yang sama. */
    public function pay(string $sku, string $customerNo, string $refId): SupplierResult;

    /** Cek status pembayaran pascabayar. */
    public function postpaidStatus(string $sku, string $customerNo, string $refId): SupplierResult;
}
