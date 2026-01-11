<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\User;
use App\Models\Batch;

class AdminController extends Controller
{
    // GET /api/admin/stats
    public function getStats()
    {
        return response()->json([
            'total_batches' => Batch::count(),
            'pending_users' => User::where('is_approved', 0)->count(),
            'active_issues' => Batch::where('halal_status', '!=', 'compliant')->count()
        ]);
    }

    // GET /api/admin/users?status=pending
    public function getUsers(Request $request)
    {
        $query = User::query();
        if ($request->status === 'pending') {
            $query->where('is_approved', 0);
        }
        return response()->json(['data' => $query->get()]);
    }

    // POST /api/admin/approve/{id}
    public function approveUser($id)
    {
        $user = User::findOrFail($id);
        $user->is_approved = 1;
        $user->save();
        return response()->json(['message' => 'User Approved']);
    }
}