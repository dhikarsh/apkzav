<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use App\Services\TransactionService;
use App\Suppliers\OtomaxSupplier;
use Illuminate\Http\Request;

/**
 * Report status dari OtomaX ke URL report reseller ZPP:
 * https://api.zppreload.com/api/v1/webhooks/otomax/{OTOMAX_REPORT_TOKEN}
 * Ref ID diambil dari parameter refid/refID, atau dicari di teks pesan.
 */
class OtomaxWebhookController extends Controller
{
    public function __invoke(Request $request, TransactionService $service, string $token)
    {
        $secret = (string) config('services.otomax.report_token');
        if ($secret === '' || ! hash_equals($secret, $token)) {
            abort(401);
        }

        $params = array_change_key_case($request->all());
        $message = (string) ($params['message'] ?? $params['msg'] ?? $params['pesan'] ?? $request->getContent());
        $refId = $params['refid'] ?? $params['ref_id'] ?? null;
        if (! $refId && preg_match('/\b((?:TRX|INQ)\d{12}[A-Z0-9]{6})\b/', $message, $m)) {
            $refId = $m[1];
        }

        $trx = $refId ? Transaction::where('ref_id', $refId)->first() : null;
        if ($trx) {
            $service->applyResult($trx, OtomaxSupplier::parseMessage($message, config('services.otomax.patterns')));
        }

        return response('OK');
    }
}
