<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Batch;
use App\Models\Checkpoint;
use Illuminate\Support\Facades\Auth;

/**
 * Handles batch CRUD operations for all roles.
 * Includes role-based filtering, search, and public consumer access.
 */
class BatchController extends Controller
{
    /**
     * List batches filtered by the authenticated user's role.
     * Admins see all batches; other roles see only their own.
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $query = Batch::query();

        // Filter by role (admins skip this — they see everything)
        if ($user->role === 'processor') {
            $query->where('processor_id', $user->id);
        } elseif ($user->role === 'logistics') {
            $query->where(function ($q) use ($user) {
                $q->where('driver_id', $user->id)
                    ->orWhere('current_holder_id', $user->id);
            });
        } elseif ($user->role === 'retailer') {
            if ($request->has('status') && $request->status === 'incoming') {
                $query->where('status', 'In Transit');
            } else {
                $query->where('current_holder_id', $user->id)
                    ->where('status', 'Delivered');
            }
        }

        // Search by batch ID or product type
        if ($request->has('search') && !empty($request->search)) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('batch_id', 'LIKE', "%{$search}%")
                    ->orWhere('product_type', 'LIKE', "%{$search}%");
            });
        }

        return response()->json(['data' => $query->get()]);
    }

    /**
     * Create a new batch and auto-log the first checkpoint entry.
     */
    public function store(Request $request)
    {
        $user = $request->user();

        $request->validate([
            'batch_id' => 'required|unique:batches',
            'product_type' => 'required',
            'weight' => 'required',
        ]);

        $batch = Batch::create([
            'batch_id' => $request->batch_id,
            'processor_id' => $user->id,
            'current_holder_id' => $user->id,
            'product_type' => $request->product_type,
            'weight' => $request->weight,
            'slaughter_date' => $request->slaughter_date ?? now(),
            'origin_farm' => $request->origin_farm,
            'processing_factory' => $request->processing_factory,
            'current_location' => $request->current_location,
            'status' => 'Processing',
            'qr_code_hash' => $request->qr_code_hash,
        ]);

        // Auto-log first audit entry
        Checkpoint::create([
            'batch_id' => $batch->id,
            'user_id' => $user->id,
            'location_name' => $request->current_location,
            'action_type' => 'arrival',
            'temperature' => 0,
            'notes' => 'Batch created in system',
        ]);

        return response()->json(['message' => 'Batch created', 'data' => $batch], 201);
    }

    /**
     * Update batch status and record the change in audit log.
     */
    public function updateStatus(Request $request)
    {
        $request->validate([
            'batch_id' => 'required|exists:batches,batch_id',
            'status' => 'required|string'
        ]);

        $batch = Batch::where('batch_id', $request->batch_id)->first();
        $batch->status = $request->status;
        $batch->save();

        // Record status change in audit log
        Checkpoint::create([
            'batch_id' => $batch->id,
            'user_id' => Auth::id(),
            'location_name' => $batch->current_location,
            'action_type' => 'transit_update',
            'temperature' => -18.0,
            'notes' => "Status updated to " . $request->status,
        ]);

        return response()->json(['message' => 'Status updated and logged']);
    }

    /**
     * Public endpoint for consumers — returns limited batch fields only.
     * No authentication required.
     */
    public function publicIndex(Request $request)
    {
        $query = Batch::query();

        if ($request->has('search') && !empty($request->search)) {
            $search = $request->search;
            $query->where('batch_id', 'LIKE', "%{$search}%")
                ->orWhere('product_type', 'LIKE', "%{$search}%");
        }

        // Only expose safe fields to the public
        $query->select([
            'id', 'batch_id', 'product_type', 'weight',
            'origin_farm', 'processing_factory', 'status',
            'halal_status', 'freshness_score', 'slaughter_date'
        ]);

        return response()->json($query->paginate(10));
    }

    /**
     * Get a single batch by ID.
     */
    public function show($id)
    {
        return response()->json(Batch::findOrFail($id));
    }
}