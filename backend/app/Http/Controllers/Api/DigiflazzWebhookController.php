<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use App\Services\TransactionService;
use App\Suppliers\DigiflazzSupplier;
use Illuminate\Http\Request;

/**
 * Callback status dari Digiflazz. Diverifikasi dengan header X-Hub-Signature
 * = "sha1=" + HMAC-SHA1(body mentah, webhook secret).
 */
class DigiflazzWebhookController extends Controller
{
    public function __invoke(Request $request, TransactionService $service)
    {
        $secret = (string) config('services.digiflazz.webhook_secret');
        $expected = 'sha1='.hash_hmac('sha1', $request->getContent(), $secret);

        if ($secret === '' || ! hash_equals($expected, (string) $request->header('X-Hub-Signature'))) {
            abort(401);
        }

        $data = $request->json('data');
        $refId = is_array($data) ? ($data['ref_id'] ?? null) : null;
        $trx = $refId ? Transaction::where('ref_id', $refId)->first() : null;

        if ($trx) {
            $service->applyResult($trx, DigiflazzSupplier::toResult($data));
        }

        return response()->json(['ok' => true]);
    }
}
