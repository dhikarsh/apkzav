<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BalanceController;
use App\Http\Controllers\Api\CatalogController;
use App\Http\Controllers\Api\DigiflazzWebhookController;
use App\Http\Controllers\Api\TransactionController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::middleware('throttle:10,1')->group(function () {
        Route::post('auth/register', [AuthController::class, 'register']);
        Route::post('auth/login', [AuthController::class, 'login']);
    });

    Route::post('webhooks/digiflazz', DigiflazzWebhookController::class);

    Route::middleware(['auth:sanctum', 'throttle:120,1'])->group(function () {
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::get('me', [AuthController::class, 'me']);
        Route::post('me/pin', [AuthController::class, 'changePin']);

        Route::get('categories', [CatalogController::class, 'categories']);
        Route::get('products', [CatalogController::class, 'products']);

        Route::get('transactions', [TransactionController::class, 'index']);
        Route::post('transactions', [TransactionController::class, 'store'])->middleware('throttle:30,1');
        Route::get('transactions/{refId}', [TransactionController::class, 'show']);
        Route::post('bills/inquiry', [TransactionController::class, 'inquiry'])->middleware('throttle:30,1');
        Route::post('bills/{refId}/pay', [TransactionController::class, 'payBill'])->middleware('throttle:30,1');

        Route::get('mutations', [BalanceController::class, 'mutations']);
        Route::get('deposits', [BalanceController::class, 'deposits']);
        Route::post('deposits', [BalanceController::class, 'createDeposit']);
    });
});
