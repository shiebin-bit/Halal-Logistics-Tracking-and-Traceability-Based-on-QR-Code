<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Batch;
use App\Models\Checkpoint;
use App\Models\Incident;
use Illuminate\Support\Facades\Auth;

/**
 * Handles logistics operations: route tracking, checkpoint submissions, and incident reporting.
 */
class LogisticsController extends Controller
{
    /**
     * Get all active (non-delivered) batches assigned to the current driver.
     * Returns formatted route data with temperature, ETA, and progress.
     */
    public function getAssignedRoutes(Request $request)
    {
        $user = $request->user();

        $batches = Batch::with('checkpoints')
            ->where(function ($q) use ($user) {
                $q->where('driver_id', $user->id)
                  ->orWhere('current_holder_id', $user->id);
            })
            ->where('status', '!=', 'Delivered')
            ->get();

        $formatted = $batches->map(function ($b) {
            $latestCheckpoint = $b->checkpoints()->latest()->first();
            $currentTemp = $latestCheckpoint ? $latestCheckpoint->temperature . "°C" : "N/A";

            $progress = 0.1;
            if ($b->status === 'In Transit') $progress = 0.5;
            if ($b->status === 'Delivered') $progress = 1.0;

            return [
                "batch_id_raw" => $b->batch_id,
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

    /**
     * Report an incident (e.g., spoilage, broken seal, delay).
     * Saves to both incidents table (for admin) and checkpoints (for audit trail).
     */
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

        // Save to incidents table for admin dashboard
        Incident::create([
            'batch_id' => $request->batch_id,
            'user_id' => $user->id,
            'issue_type' => $request->issue_type,
            'description' => $request->description,
            'location' => $request->location,
            'status' => 'Open',
        ]);

        // Log to checkpoints for audit trail
        Checkpoint::create([
            'batch_id' => $batch->id,
            'user_id' => $user->id,
            'location_name' => $request->location,
            'action_type' => 'transit_update',
            'temperature' => 0,
            'notes' => "[INCIDENT: " . $request->issue_type . "] " . $request->description,
        ]);

        return response()->json(['message' => 'Incident reported successfully']);
    }

    /**
     * Submit a checkpoint scan (temperature, location, signature).
     * Handles custody transfer: if the scanner is not the current holder,
     * ownership is transferred and status is updated based on the scanner's role.
     */
    public function submitCheckpoint(Request $request)
    {
        $request->validate([
            'batch_id' => 'required|exists:batches,batch_id',
            'temperature' => 'required',
            'location' => 'required'
        ]);

        $user = Auth::user();
        $batch = Batch::where('batch_id', $request->batch_id)->firstOrFail();

        $actionType = 'transit_update';
        $notes = $request->notes;

        // If scanner is not the current holder, transfer custody
        if ($batch->current_holder_id != $user->id) {
            $batch->current_holder_id = $user->id;

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

        // Record checkpoint in audit trail
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