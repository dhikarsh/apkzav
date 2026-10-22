<?php

namespace App\Suppliers;

/** Hasil satu panggilan ke supplier, sudah dinormalkan ke status internal. */
final class SupplierResult
{
    public function __construct(
        public readonly string $status, // pending | success | failed
        public readonly ?string $sn = null,
        public readonly ?string $rc = null,
        public readonly ?string $message = null,
        public readonly ?int $cost = null,
        public readonly array $raw = [],
        public readonly ?string $customerName = null,
        public readonly array $detail = [],
    ) {}
}
