<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\TransactionResource;
use App\Models\BillInquiry;
use App\Models\Product;
use App\Services\TransactionService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class TransactionController extends Controller
{
    public function __construct(private readonly TransactionService $service) {}

    public function index(Request $request)
    {
        $request->validate(['status' => ['nullable', 'in:pending,success,failed']]);

        return TransactionResource::collection(
            $request->user()->transactions()
                ->with('product')
                ->when($request->status, fn ($q, $v) => $q->where('status', $v))
                ->latest('id')
                ->paginate(20)
        );
    }

    public function show(Request $request, string $refId)
    {
        $trx = $request->user()->transactions()->with('product')->where('ref_id', $refId)->firstOrFail();

        return new TransactionResource($trx);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'sku' => ['required', 'string'],
            'customer_no' => ['required', 'string', 'max:50'],
            'pin' => ['required', 'string'],
        ]);
        $this->checkPin($request, $data['pin']);

        $product = Product::where('sku', $data['sku'])->firstOrFail();
        $trx = $this->service->purchase($request->user(), $product, $data['customer_no']);

        return (new TransactionResource($trx->load('product')))->response()->setStatusCode(201);
    }

    public function inquiry(Request $request)
    {
        $data = $request->validate([
            'sku' => ['required', 'string'],
            'customer_no' => ['required', 'string', 'max:50'],
        ]);

        $product = Product::where('sku', $data['sku'])->firstOrFail();
        $bill = $this->service->inquiry($request->user(), $product, $data['customer_no']);

        return response()->json([
            'ref_id' => $bill->ref_id,
            'product' => $product->name,
            'customer_no' => $bill->customer_no,
            'customer_name' => $bill->customer_name,
            'price' => $bill->price,
            'detail' => $bill->detail,
            'expires_at' => $bill->expires_at,
        ]);
    }

    public function payBill(Request $request, string $refId)
    {
        $data = $request->validate(['pin' => ['required', 'string']]);
        $this->checkPin($request, $data['pin']);

        $bill = BillInquiry::where('ref_id', $refId)->where('user_id', $request->user()->id)->firstOrFail();
        $trx = $this->service->payBill($request->user(), $bill);

        return (new TransactionResource($trx->load('product')))->response()->setStatusCode(201);
    }

    private function checkPin(Request $request, string $pin): void
    {
        if (! Hash::check($pin, $request->user()->pin)) {
            throw ValidationException::withMessages(['pin' => 'PIN salah']);
        }
    }
}
