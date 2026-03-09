<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// Temporary debug endpoint for validating payload shape from clients.
Route::post('/', function (Request $request) {
    return response()->json([
        'message' => 'User registered successfully',
        'data' => $request->all()
    ]);
});
