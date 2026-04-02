<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Batch;
use App\Models\Checkpoint;
use App\Models\Incident;
use Illuminate\Http\Request;

class RetailerController extends Controller
{
    public function incoming(Request $request)
    {
        $user = $request->user();
        $retailerProfile = $user->retailerProfile;
        $searchTerms = $this->buildRetailerSearchTerms($retailerProfile);

        $batches = Batch::with(['processor', 'driver'])
            ->whereIn('status', ['QR Generated', 'In Transit'])
            ->where(function ($query) use ($searchTerms) {
                foreach ($searchTerms as $term) {
                    $query->orWhere('destination_address', 'LIKE', "%{$term}%");
                }
            })
            ->get();

        $formatted = $batches->map(function (Batch $batch) {
            return [
                'batch_id' => $batch->batch_id,
                'product_type' => $batch->product_type,
                'weight' => $batch->weight,
                'origin' => $batch->origin_farm,
                'status' => $batch->status,
                'driver' => $batch->driver->name ?? 'Unassigned',
                'phone' => $batch->driver->phone_number ?? 'N/A',
                'truck_plate' => $batch->truck_plate ?? 'N/A',
                'eta' => $batch->estimated_arrival,
                'freshness' => $batch->freshness_score,
                'certificate_no' => $batch->certificate_no,
            ];
        });

        return response()->json(['data' => $formatted]);
    }

    public function inventory(Request $request)
    {
        $user = $request->user();

        $batches = Batch::where('current_holder_id', $user->id)
            ->where('status', 'Delivered')
            ->orderBy('updated_at', 'desc')
            ->get();

        $formatted = $batches->map(function (Batch $batch) {
            return [
                'batch_id' => $batch->batch_id,
                'product_type' => $batch->product_type,
                'weight' => $batch->weight,
                'origin' => $batch->origin_farm,
                'status' => $batch->status,
                'freshness' => $batch->freshness_score,
                'received_at' => $batch->updated_at->format('Y-m-d H:i'),
            ];
        });

        return response()->json(['data' => $formatted]);
    }

    public function accept(Request $request)
    {
        $request->validate([
            'batch_id' => 'required|exists:batches,batch_id',
            'quality_checks' => 'required|array',
            'arrival_temperature' => 'required|numeric|between:-40,20',
        ]);

        $user = $request->user();
        $batch = Batch::where('batch_id', $request->batch_id)->firstOrFail();

        $this->ensureRetailerCanManageBatch($batch, $user);
        $requiredChecks = [
            'packaging_intact',
            'temperature_check',
            'halal_cert_present',
            'quantity_match',
            'expiry_valid',
        ];
        foreach ($requiredChecks as $key) {
            abort_if(
                !array_key_exists($key, $request->quality_checks) || $request->quality_checks[$key] !== true,
                422,
                'All mandatory retail quality checks must be completed before acceptance.'
            );
        }

        abort_if(!$batch->hasActiveQr(), 422, 'This batch is not ready for retail verification.');
        abort_if($batch->status === 'Rejected', 409, 'Rejected batches cannot be accepted.');
        abort_if(
            $batch->incidents()->where('status', '!=', 'Resolved')->exists(),
            409,
            'This batch has unresolved incidents and cannot be accepted yet.'
        );

        $batch->current_holder_id = $user->id;
        $batch->status = 'Delivered';
        $batch->current_location = $user->retailerProfile->outlet_address
            ?? $user->retailerProfile->store_name
            ?? 'Retailer Store';
        $batch->save();

        Checkpoint::create([
            'batch_id' => $batch->id,
            'user_id' => $user->id,
            'location_name' => $batch->current_location,
            'temperature' => $request->arrival_temperature,
            'action_type' => 'arrival',
            'notes' => 'Retail acceptance completed.',
        ]);

        return response()->json(['message' => 'Shipment accepted successfully.']);
    }

    public function reject(Request $request)
    {
        $request->validate([
            'batch_id' => 'required|exists:batches,batch_id',
            'reason' => 'required|string|min:5',
            'arrival_temperature' => 'required|numeric|between:-40,20',
            'severity' => 'nullable|in:minor,moderate,severe',
        ]);

        $user = $request->user();
        $batch = Batch::where('batch_id', $request->batch_id)->firstOrFail();

        $this->ensureRetailerCanManageBatch($batch, $user);

        abort_if(!$batch->hasActiveQr(), 422, 'This batch is not ready for retail verification.');
        abort_if($batch->status === 'Delivered', 409, 'Delivered batches cannot be rejected.');
        abort_if($batch->status === 'Rejected', 409, 'This batch was already rejected.');

        $batch->status = 'Rejected';
        $batch->halal_status = 'investigation';
        $batch->save();

        Incident::create([
            'batch_id' => $batch->batch_id,
            'user_id' => $user->id,
            'issue_type' => 'Retail Rejection',
            'description' => $request->reason,
            'location' => $user->retailerProfile->outlet_address ?? 'Retailer',
            'status' => 'Open',
            'severity' => $request->severity === 'severe' ? 'critical' : ($request->severity ?? 'moderate'),
        ]);

        Checkpoint::create([
            'batch_id' => $batch->id,
            'user_id' => $user->id,
            'location_name' => $user->retailerProfile->outlet_address ?? 'Retailer',
            'temperature' => $request->arrival_temperature,
            'action_type' => 'arrival',
            'notes' => 'Retail rejection recorded.',
        ]);

        return response()->json(['message' => 'Shipment rejected and flagged for investigation.']);
    }

    private function buildRetailerSearchTerms($retailerProfile): array
    {
        if (!$retailerProfile) {
            return [];
        }

        $excludedWords = [
            'outlet', 'store', 'jalan', 'road', 'street', 'lorong',
            'taman', 'bandar', 'blok', 'block', 'mall', 'plaza',
            'floor', 'level', 'suite', 'unit', 'lot',
        ];

        $searchTerms = [];
        $storeName = $retailerProfile->store_name ?? '';
        $outletAddress = $retailerProfile->outlet_address ?? '';

        if ($storeName) {
            $words = preg_split('/\s+/', trim($storeName));
            $searchTerms[] = count($words) >= 2 ? implode(' ', array_slice($words, 0, 2)) : $storeName;
        }

        if ($outletAddress) {
            $searchTerms[] = $outletAddress;
            $addrWords = preg_split('/\s+/', str_replace([',', '.'], '', $outletAddress));
            foreach ($addrWords as $word) {
                $word = trim($word);
                if (strlen($word) >= 5 && !in_array(strtolower($word), $excludedWords, true)) {
                    $searchTerms[] = $word;
                }
            }
        }

        return array_values(array_unique(array_filter($searchTerms)));
    }

    private function batchMatchesRetailer(Batch $batch, $retailerProfile): bool
    {
        $destination = strtolower((string) ($batch->destination_address ?? ''));
        if ($destination === '') {
            return false;
        }

        foreach ($this->buildRetailerSearchTerms($retailerProfile) as $term) {
            if (str_contains($destination, strtolower($term))) {
                return true;
            }
        }

        return false;
    }

    private function ensureRetailerCanManageBatch(Batch $batch, $user): void
    {
        $isCurrentHolder = (int) $batch->current_holder_id === (int) $user->id;
        $matchesRetailer = $this->batchMatchesRetailer($batch, $user->retailerProfile);

        abort_unless(
            $isCurrentHolder || $matchesRetailer,
            403,
            'This batch is not assigned to this retailer.'
        );
    }
}
