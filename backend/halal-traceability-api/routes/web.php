<?php

use Illuminate\Http\Request;

// This handles the POST request to '/'
Route::post('/', function (Request $request) {
    // Logic to create the "Processor" user
    return response()->json([
        'message' => 'User registered successfully',
        'data' => $request->all()
    ]);
});
