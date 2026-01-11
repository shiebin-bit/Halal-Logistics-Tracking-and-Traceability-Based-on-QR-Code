<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class UserController extends Controller
{
    // GET /api/user
    public function show(Request $request)
    {
        $user = $request->user();

        // Dynamically load the profile based on the role
        if ($user->role === 'logistics') {
            $user->load('logisticsProfile');
        } elseif ($user->role === 'processor') {
            $user->load('processorProfile');
        } elseif ($user->role === 'retailer') {
            $user->load('retailerProfile');
        }

        return response()->json([
            'user' => $user
        ]);
    }
}