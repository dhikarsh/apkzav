<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'digiflazz' => [
        'username' => env('DIGIFLAZZ_USERNAME'),
        'api_key' => env('DIGIFLAZZ_API_KEY'),
        'webhook_secret' => env('DIGIFLAZZ_WEBHOOK_SECRET'),
        // true = kirim flag testing (pakai Development Key Digiflazz saat uji coba).
        'testing' => env('DIGIFLAZZ_TESTING', true),
    ],

    // Supplier aktif: "digiflazz" atau "otomax" (IP Center OtomaX sendiri, lewat VPN).
    'supplier' => env('SUPPLIER', 'digiflazz'),

    'otomax' => [
        // Alamat IP Center OtomaX, mis. http://10.244.165.1:5859 (lihat "Kirim Ke" di setting IP Center).
        'base_url' => env('OTOMAX_URL'),
        'path' => env('OTOMAX_PATH', 'trx'),
        'member_id' => env('OTOMAX_MEMBER_ID'),
        'pin' => env('OTOMAX_PIN'),
        'password' => env('OTOMAX_PASSWORD'),
        'timeout' => (int) env('OTOMAX_TIMEOUT', 30),
        // Kode produk pascabayar di OtomaX; {sku} diganti SKU produk di panel admin.
        'inquiry_product' => env('OTOMAX_INQUIRY_PRODUCT', 'CEK{sku}'),
        'pay_product' => env('OTOMAX_PAY_PRODUCT', 'BYR{sku}'),
        // Token rahasia di URL report: /api/v1/webhooks/otomax/{token}
        'report_token' => env('OTOMAX_REPORT_TOKEN'),
        // Pola pembaca pesan OtomaX (regex). Kosong = pakai bawaan OtomaxSupplier::defaultPatterns().
        'patterns' => array_filter([
            'success_pattern' => env('OTOMAX_SUCCESS_PATTERN'),
            'failed_pattern' => env('OTOMAX_FAILED_PATTERN'),
            'sn_pattern' => env('OTOMAX_SN_PATTERN'),
            'price_pattern' => env('OTOMAX_PRICE_PATTERN'),
        ]),
    ],

    'ppob' => [
        'deposit_bank_info' => env('DEPOSIT_BANK_INFO'),
        'deposit_min' => (int) env('DEPOSIT_MIN', 10000),
        // Tagihan hasil inquiry kedaluwarsa setelah N menit.
        'inquiry_ttl_minutes' => (int) env('INQUIRY_TTL_MINUTES', 30),
    ],

];
