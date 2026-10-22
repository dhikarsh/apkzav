<?php

use App\Services\InsufficientBalanceException;
use App\Services\TransactionException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        //
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->render(fn (TransactionException $e) => response()->json(['message' => $e->getMessage()], 422));
        $exceptions->render(fn (InsufficientBalanceException $e) => response()->json([
            'message' => 'Saldo tidak cukup',
            'balance' => $e->balance,
            'required' => $e->required,
        ], 422));
    })->create();
