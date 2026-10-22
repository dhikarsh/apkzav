<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\Level;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'phone' => ['required', 'regex:/^08[0-9]{8,13}$/', 'unique:users,phone'],
            'pin' => ['required', 'digits:6'],
            'upline_phone' => ['nullable', 'exists:users,phone'],
            'device_name' => ['required', 'string', 'max:100'],
        ]);

        $user = User::create([
            'name' => $data['name'],
            'phone' => $data['phone'],
            'pin' => $data['pin'],
            'level_id' => Level::default()?->id,
            'upline_id' => isset($data['upline_phone']) ? User::where('phone', $data['upline_phone'])->value('id') : null,
            'device_id' => $data['device_name'],
        ]);

        return response()->json([
            'token' => $user->createToken($data['device_name'])->plainTextToken,
            'user' => new UserResource($user),
        ], 201);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'phone' => ['required', 'string'],
            'pin' => ['required', 'string'],
            'device_name' => ['required', 'string', 'max:100'],
        ]);

        $user = User::where('phone', $data['phone'])->first();

        if (! $user || ! Hash::check($data['pin'], $user->pin)) {
            throw ValidationException::withMessages(['phone' => 'Nomor HP atau PIN salah']);
        }
        if (! $user->is_active) {
            throw ValidationException::withMessages(['phone' => 'Akun dinonaktifkan, hubungi CS']);
        }

        $user->update(['device_id' => $data['device_name']]);

        return response()->json([
            'token' => $user->createToken($data['device_name'])->plainTextToken,
            'user' => new UserResource($user),
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->noContent();
    }

    public function me(Request $request)
    {
        return new UserResource($request->user()->load('level'));
    }

    public function changePin(Request $request)
    {
        $data = $request->validate([
            'old_pin' => ['required', 'string'],
            'new_pin' => ['required', 'digits:6', 'confirmed'],
        ]);

        if (! Hash::check($data['old_pin'], $request->user()->pin)) {
            throw ValidationException::withMessages(['old_pin' => 'PIN lama salah']);
        }

        $request->user()->update(['pin' => $data['new_pin']]);

        return response()->noContent();
    }
}
