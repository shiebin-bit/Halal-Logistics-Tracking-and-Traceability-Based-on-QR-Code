<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Batch;
use App\Models\Checkpoint;
use Illuminate\Support\Facades\Auth;

class LogisticsController extends Controller
{
    // GET /api/logistics/routes
    public function getAssignedRoutes(Request $request)
    {
        $user = $request->user();

        $batches = Batch::with('checkpoints')
            ->where('driver_id', $user->id)
            ->orWhere('current_holder_id', $user->id)
            ->where('status', '!=', 'Delivered')
            ->get();

        $formatted = $batches->map(function ($b) {
            $latestCheckpoint = $b->checkpoints()->latest()->first();
            $currentTemp = $latestCheckpoint ? $latestCheckpoint->temperature . "°C" : "N/A";

            $progress = 0.1;
            if ($b->status === 'In Transit')
                $progress = 0.5;
            if ($b->status === 'Delivered')
                $progress = 1.0;

            return [
                "batch_id_raw" => $b->batch_id, // <--- ADDED THIS for Dropdown
                "truckId" => $b->truck_plate ?? "Assigning...",
                "destination" => $b->destination_address ?? "See Manifest",
                "eta" => $b->estimated_arrival ? date('H:i', strtotime($b->estimated_arrival)) : "TBD",
                "temp" => $currentTemp,
                "status" => $b->status,
                "progress" => $progress
            ];
        });

        return response()->json(['data' => $formatted]);
    }

    // POST /api/logistics/incident
    public function reportIncident(Request $request)
    {
        $request->validate([
            'batch_id' => 'required|exists:batches,batch_id',
            'issue_type' => 'required|string',
            'description' => 'required|string',
            'location' => 'required|string',
        ]);

        $user = Auth::user();
        $batch = Batch::where('batch_id', $request->batch_id)->firstOrFail();

        // We record incidents as a checkpoint with a special tag in the notes
        // This ensures it shows up in the Audit Log automatically.
        Checkpoint::create([
            'batch_id' => $batch->id,
            'user_id' => $user->id,
            'location_name' => $request->location,
            'action_type' => 'transit_update', // Keeping enum strict, using notes for detail
            'temperature' => 0,
            'notes' => "[INCIDENT: " . $request->issue_type . "] " . $request->description,
        ]);

        // Optional: You could update batch status to 'On Hold' if it's severe

        return response()->json(['message' => 'Incident reported successfully']);
    }

    // ... (Keep submitCheckpoint as is) ...
    public function submitCheckpoint(Request $request)
    {
        // ... (Keep Validation) ...
        $request->validate([
            'batch_id' => 'required|exists:batches,batch_id',
            'temperature' => 'required',
            'location' => 'required'
        ]);

        $user = Auth::user();
        $batch = Batch::where('batch_id', $request->batch_id)->firstOrFail();

        $actionType = 'transit_update';
        $notes = $request->notes;

        // --- NEW LOGIC: ROLE BASED ACTIONS ---
        if ($batch->current_holder_id != $user->id) {

            // 1. Transfer Ownership
            $batch->current_holder_id = $user->id;

            // 2. Set Status based on Role
            if ($user->role === 'retailer') {
                $batch->status = 'Delivered';
                $batch->destination_address = $user->retailerProfile->outlet_address ?? $request->location;
                $actionType = 'arrival';
                $notes = "Received by Retailer. Final Delivery.";
            } elseif ($user->role === 'logistics') {
                $batch->status = 'In Transit';
                $batch->driver_id = $user->id;
                if ($user->logisticsProfile) {
                    $batch->truck_plate = $user->logisticsProfile->vehicle_plate_no;
                }
                $actionType = 'handover';
                $notes = "Custody transferred to Logistics Driver.";
            }

            $batch->save();
        }
        // -------------------------------------

        Checkpoint::create([
            'batch_id' => $batch->id,
            'user_id' => $user->id,
            'location_name' => $request->location,
            'temperature' => $request->temperature,
            'action_type' => $actionType,
            'notes' => $notes,
            'signature_path' => $request->signature
        ]);

        return response()->json(['message' => 'Checkpoint recorded successfully']);
    }
}