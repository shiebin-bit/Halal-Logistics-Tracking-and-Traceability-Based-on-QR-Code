<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

/**
 * Returns the authenticated user's profile with role-specific data.
 */
class UserController extends Controller
{
    /** Get the current user with their role-specific profile loaded. */
    public function show(Request $request)
    {
        $user = $request->user();

        // Load the role-specific profile relation
        if ($user->role === 'logistics') {
            $user->load('logisticsProfile');
        } elseif ($user->role === 'processor') {
            $user->load('processorProfile');
        } elseif ($user->role === 'retailer') {
            $user->load('retailerProfile');
        }

        return response()->json(['user' => $user]);
    }
}