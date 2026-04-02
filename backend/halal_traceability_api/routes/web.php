<?php

use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;

// Temporary debug endpoint for validating payload shape from clients.
Route::post('/', function (Request $request) {
    return response()->json([
        'message' => 'User registered successfully',
        'data' => $request->all()
    ]);
});

Route::get('/reset-password', function (Request $request) {
    abort_unless($request->filled('token') && $request->filled('email'), 404);

    return view('auth.reset-password', [
        'token' => (string) $request->query('token'),
        'email' => (string) $request->query('email'),
        'status' => session('status'),
    ]);
})->name('password.reset');

Route::post('/reset-password', function (Request $request) {
    $validated = $request->validate([
        'token' => ['required', 'string'],
        'email' => ['required', 'email'],
        'password' => ['required', 'confirmed', 'min:8'],
    ]);

    $status = Password::reset(
        $validated,
        function ($user, string $password): void {
            $user->forceFill([
                'password' => Hash::make($password),
                'remember_token' => Str::random(60),
            ])->save();
        }
    );

    if ($status === Password::PASSWORD_RESET) {
        return back()->with('status', __($status));
    }

    return back()->withErrors([
        'email' => __($status),
    ])->onlyInput('email');
})->name('password.update');
