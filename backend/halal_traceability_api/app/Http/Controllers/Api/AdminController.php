<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\User;
use App\Models\Batch;
use App\Models\Incident;

/**
 * Admin-only controller for managing users, viewing stats, and monitoring incidents.
 * Each method checks admin role before executing.
 */
class AdminController extends Controller
{
    /** Get dashboard statistics (total batches, pending users, active incidents). */
    public function getStats(Request $request)
    {
        return response()->json([
            'total_batches' => Batch::count(),
            'pending_users' => User::where('is_approved', 0)->count(),
            'active_issues' => Incident::where('status', '!=', 'Resolved')->count()
        ]);
    }

    /** List users, optionally filtered by approval status. */
    public function getUsers(Request $request)
    {
        $query = User::query();
        if ($request->status === 'pending') {
            $query->where('is_approved', 0);
        }
        return response()->json(['data' => $query->get()]);
    }

    /** Approve a pending user registration. */
    public function approveUser($id)
    {
        $user = User::findOrFail($id);
        $user->is_approved = 1;
        $user->save();
        return response()->json(['message' => 'User Approved']);
    }

    /** Reject and delete a pending user registration. */
    public function rejectUser($id)
    {
        $user = User::findOrFail($id);
        $user->delete();
        return response()->json(['message' => 'User Rejected and Removed']);
    }

    /** List all incidents, newest first. */
    public function getIncidents()
    {
        return response()->json(['data' => Incident::orderBy('created_at', 'desc')->get()]);
    }
}