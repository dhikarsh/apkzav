<?php

namespace App\Services;

use RuntimeException;

class InsufficientBalanceException extends RuntimeException
{
    public function __construct(public readonly int $balance, public readonly int $required)
    {
        parent::__construct('Saldo tidak cukup');
    }
}
