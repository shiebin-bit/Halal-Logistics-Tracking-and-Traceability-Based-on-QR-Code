<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Batch;
use App\Models\Checkpoint;
use Illuminate\Support\Facades\Auth;

class BatchController extends Controller
{
    // GET /api/batches
    public function index(Request $request)
    {
        $user = $request->user();

        if ($user->role === 'processor') {
            // Processors see batches they created
            $batches = Batch::where('processor_id', $user->id)->get();
        } elseif ($user->role === 'logistics') {
            // Drivers see batches assigned to them OR currently holding
            $batches = Batch::where('driver_id', $user->id)
                ->orWhere('current_holder_id', $user->id)
                ->get();
        } elseif ($user->role === 'retailer') {
            // Retailers see batches currently at their store
            $batches = Batch::where('current_holder_id', $user->id)->get();
        } else {
            $batches = [];
        }

        return response()->json(['data' => $batches]);
    }

    // POST /api/batches (Create New)
    public function store(Request $request)
    {
        $user = $request->user();

        // 1. Validate
        $request->validate([
            'batch_id' => 'required|unique:batches',
            'product_type' => 'required',
            'weight' => 'required',
        ]);

        // 2. Create Batch
        $batch = Batch::create([
            'batch_id' => $request->batch_id,
            'processor_id' => $user->id,
            'current_holder_id' => $user->id, // Starts with Processor
            'product_type' => $request->product_type,
            'weight' => $request->weight,
            'slaughter_date' => $request->slaughter_date ?? now(),
            'origin_farm' => $request->origin_farm,
            'processing_factory' => $request->processing_factory,
            'current_location' => $request->current_location,
            'status' => 'Processing',
            'qr_code_hash' => $request->qr_code_hash,
        ]);

        // 3. AUTO-LOG: Create the first Audit Entry (Checkpoint)
        Checkpoint::create([
            'batch_id' => $batch->id,
            'user_id' => $user->id,
            'location_name' => $request->current_location,
            'action_type' => 'arrival', // Or 'creation'
            'temperature' => 0, // Default
            'notes' => 'Batch created in system',
        ]);

        return response()->json(['message' => 'Batch created', 'data' => $batch], 201);
    }

    // POST /api/batches/update-status
    public function updateStatus(Request $request)
    {
        $request->validate([
            'batch_id' => 'required|exists:batches,batch_id',
            'status' => 'required|string'
        ]);

        $batch = Batch::where('batch_id', $request->batch_id)->first();
        $batch->status = $request->status;
        $batch->save();

        // --- FIX: RECORD THIS IN AUDIT LOG ---
        Checkpoint::create([
            'batch_id' => $batch->id, // Database ID, not String ID
            'user_id' => Auth::id(),
            'location_name' => $batch->current_location, // Use last known location
            'action_type' => 'transit_update',
            'temperature' => -18.0, // Default safe temp if not provided
            'notes' => "Status updated to " . $request->status,
        ]);

        return response()->json(['message' => 'Status updated and logged']);
    }

    // Public Search
    // GET /api/public/batches
    public function publicIndex(Request $request)
    {
        $query = Batch::query();

        // 1. Handle Search (Batch ID or Product Name)
        if ($request->has('search') && !empty($request->search)) {
            $search = $request->search;
            $query->where('batch_id', 'LIKE', "%{$search}%")
                ->orWhere('product_type', 'LIKE', "%{$search}%");
        }

        // 2. Only show "safe" fields to public (Security Best Practice)
        $query->select([
            'id',
            'batch_id',
            'product_type',
            'weight',
            'origin_farm',
            'processing_factory',
            'status',
            'halal_status',
            'freshness_score',
            'slaughter_date'
        ]);

        // 3. Return Paginator (Flutter code expects 'data' key, which paginate provides)
        return response()->json($query->paginate(10));
    }

    public function show($id)
    {
        return response()->json(Batch::findOrFail($id));
    }
}