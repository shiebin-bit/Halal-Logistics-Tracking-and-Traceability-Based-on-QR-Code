<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Batch;
use App\Models\Checkpoint;
use Illuminate\Support\Facades\Auth;

/**
 * Handles retailer operations: viewing incoming shipments,
 * managing received inventory, and accepting/rejecting deliveries.
 */
class RetailerController extends Controller
{
    /**
     * Get batches that are heading towards this retailer (In Transit / Ready).
     * Matches by destination_address containing the retailer's store name,
     * or by batches assigned to a driver with destination matching the retailer.
     */
    public function incoming(Request $request)
    {
        $user = $request->user();

        // Get the retailer's store info for matching
        $retailerProfile = $user->retailerProfile;
        $storeName = $retailerProfile->store_name ?? '';
        $outletAddress = $retailerProfile->outlet_address ?? '';

        // Build flexible search terms for destination matching
        // Use store name prefix (first 2 words) for broad matching
        // e.g. "Fresh Mart Kuala Lumpur" → search for "Fresh Mart"
        $searchTerms = [];

        if ($storeName) {
            $words = explode(' ', $storeName);
            if (count($words) >= 2) {
                $searchTerms[] = implode(' ', array_slice($words, 0, 2));
            } else {
                $searchTerms[] = $storeName;
            }
        }

        // Also extract significant keywords from outlet address (≥5 chars)
        if ($outletAddress) {
            $addrWords = explode(' ', str_replace([',', '.'], '', $outletAddress));
            foreach ($addrWords as $word) {
                $word = trim($word);
                if (strlen($word) >= 5) {
                    $searchTerms[] = $word;
                }
            }
        }

        // Find batches headed to this retailer that haven't been delivered yet
        $batches = Batch::with(['processor', 'driver'])
            ->where('status', '!=', 'Delivered')
            ->where('status', '!=', 'Processing')
            ->where(function ($query) use ($searchTerms) {
                foreach ($searchTerms as $term) {
                    $query->orWhere('destination_address', 'LIKE', "%{$term}%");
                }
            })
            ->get();

        $formatted = $batches->map(function ($b) {
            return [
                'batch_id' => $b->batch_id,
                'product_type' => $b->product_type,
                'weight' => $b->weight,
                'origin' => $b->origin_farm,
                'status' => $b->status,
                'driver' => $b->driver->name ?? 'Unassigned',
                'phone' => $b->driver->phone_number ?? 'N/A',
                'truck_plate' => $b->truck_plate ?? 'N/A',
                'eta' => $b->estimated_arrival,
                'freshness' => $b->freshness_score,
            ];
        });

        return response()->json(['data' => $formatted]);
    }

    /**
     * Get batches currently held by this retailer (Delivered status).
     * These are batches the retailer has accepted via scan.
     */
    public function inventory(Request $request)
    {
        $user = $request->user();

        $batches = Batch::where('current_holder_id', $user->id)
            ->where('status', 'Delivered')
            ->orderBy('updated_at', 'desc')
            ->get();

        $formatted = $batches->map(function ($b) {
            return [
                'batch_id' => $b->batch_id,
                'product_type' => $b->product_type,
                'weight' => $b->weight,
                'origin' => $b->origin_farm,
                'status' => $b->status,
                'freshness' => $b->freshness_score,
                'received_at' => $b->updated_at->format('Y-m-d H:i'),
            ];
        });

        return response()->json(['data' => $formatted]);
    }

    /**
     * Accept a batch delivery after quality inspection.
     * Transfers custody to the retailer and marks the batch as Delivered.
     */
    public function accept(Request $request)
    {
        $request->validate([
            'batch_id' => 'required|exists:batches,batch_id',
            'quality_checks' => 'required|array',
        ]);

        $user = $request->user();
        $batch = Batch::where('batch_id', $request->batch_id)->firstOrFail();

        // Transfer custody to retailer
        $batch->current_holder_id = $user->id;
        $batch->status = 'Delivered';
        $batch->current_location = $user->retailerProfile->outlet_address
            ?? $user->retailerProfile->store_name
            ?? 'Retailer Store';
        $batch->save();

        // Log the acceptance as a checkpoint
        Checkpoint::create([
            'batch_id' => $batch->id,
            'user_id' => $user->id,
            'location_name' => $batch->current_location,
            'temperature' => 0,
            'action_type' => 'arrival',
            'notes' => 'Accepted by Retailer. Quality checks passed: '
                . implode(', ', array_keys(array_filter($request->quality_checks))),
        ]);

        return response()->json(['message' => 'Shipment accepted successfully']);
    }

    /**
     * Reject a batch delivery. Flags the batch for investigation.
     */
    public function reject(Request $request)
    {
        $request->validate([
            'batch_id' => 'required|exists:batches,batch_id',
        ]);

        $user = $request->user();
        $batch = Batch::where('batch_id', $request->batch_id)->firstOrFail();

        // Mark batch as under investigation
        $batch->halal_status = 'investigation';
        $batch->save();

        // Log the rejection as a checkpoint
        Checkpoint::create([
            'batch_id' => $batch->id,
            'user_id' => $user->id,
            'location_name' => $user->retailerProfile->outlet_address ?? 'Retailer',
            'temperature' => 0,
            'action_type' => 'arrival',
            'notes' => 'REJECTED by Retailer. Batch flagged for investigation.',
        ]);

        return response()->json(['message' => 'Shipment rejected and flagged']);
    }
}
