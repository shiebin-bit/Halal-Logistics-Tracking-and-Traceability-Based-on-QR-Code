<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Batch;
use App\Models\Checkpoint;
use App\Models\Incident;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class LogisticsController extends Controller
{
    public function getAssignedRoutes(Request $request)
    {
        $user = $request->user();

        $batches = Batch::with('checkpoints')
            ->where(function ($q) use ($user) {
                $q->where('driver_id', $user->id)
                    ->orWhere('current_holder_id', $user->id);
            })
            ->whereNotIn('status', ['Delivered', 'Rejected', 'Invalid - Certificate Revoked'])
            ->get();

        $formatted = $batches->map(function (Batch $batch) {
            $latestCheckpoint = $batch->checkpoints()->latest()->first();
            $currentTemp = $latestCheckpoint ? $latestCheckpoint->temperature.'°C' : 'N/A';
            $progress = match ($batch->status) {
                'QR Generated' => 0.2,
                'In Transit' => 0.6,
                'Delivered' => 1.0,
                default => 0.1,
            };

            return [
                'id' => $batch->id,
                'batch_id_raw' => $batch->batch_id,
                'truckId' => $batch->truck_plate ?? 'Assigning...',
                'destination' => $batch->destination_address ?? 'See manifest',
                'eta' => $batch->estimated_arrival?->format('H:i') ?? 'TBD',
                'temp' => $currentTemp,
                'status' => $batch->status,
                'progress' => $progress,
            ];
        });

        return response()->json(['data' => $formatted]);
    }

    public function reportIncident(Request $request)
    {
        $request->validate([
            'batch_id' => 'required|exists:batches,batch_id',
            'issue_type' => 'required|string',
            'description' => 'required|string',
            'location' => 'required|string',
            'severity' => 'nullable|in:minor,moderate,critical',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
        ]);

        $user = Auth::user();
        $batch = Batch::where('batch_id', $request->batch_id)->firstOrFail();

        abort_if(!$batch->hasActiveQr(), 422, 'This batch is not ready for logistics tracking.');
        abort_if(in_array($batch->status, ['Delivered', 'Rejected'], true), 409, 'This batch can no longer receive logistics incidents.');

        $this->ensureBatchBelongsToLogistics($batch, $user->id, false);

        Incident::create([
            'batch_id' => $request->batch_id,
            'user_id' => $user->id,
            'issue_type' => $request->issue_type,
            'description' => $request->description,
            'location' => $request->location,
            'status' => 'Open',
            'severity' => $request->severity ?? 'moderate',
        ]);

        Checkpoint::create([
            'batch_id' => $batch->id,
            'user_id' => $user->id,
            'location_name' => $request->location,
            'latitude' => $request->latitude,
            'longitude' => $request->longitude,
            'action_type' => 'incident',
            'temperature' => 0,
            'notes' => 'Incident reported during transit.',
        ]);

        return response()->json(['message' => 'Incident reported successfully.']);
    }

    public function submitCheckpoint(Request $request)
    {
        $request->validate([
            'batch_id' => 'required|exists:batches,batch_id',
            'temperature' => 'required|numeric|between:-40,20',
            'location' => 'required|string',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'signature' => 'required|string',
            'notes' => 'nullable|string',
        ]);

        $user = Auth::user();
        $batch = Batch::where('batch_id', $request->batch_id)->firstOrFail();

        abort_if(!$batch->hasActiveQr(), 422, 'This batch has not completed halal validation and QR generation yet.');
        abort_if(in_array($batch->status, ['Delivered', 'Rejected'], true), 409, 'Delivered or rejected batches can no longer receive checkpoints.');

        $this->ensureBatchBelongsToLogistics($batch, $user->id, true);

        if ((int) $batch->current_holder_id !== (int) $user->id) {
            $batch->current_holder_id = $user->id;
        }

        $batch->status = 'In Transit';
        $batch->driver_id = $user->id;
        $batch->current_location = $request->location;

        if ($user->logisticsProfile) {
            $batch->truck_plate = $user->logisticsProfile->vehicle_plate_no;
        }

        $batch->save();

        $notes = trim((string) $request->notes);
        if ($request->temperature < 0 || $request->temperature > 4) {
            $notes = trim('[TEMP ALERT] '.$notes);
        }

        Checkpoint::create([
            'batch_id' => $batch->id,
            'user_id' => $user->id,
            'location_name' => $request->location,
            'latitude' => $request->latitude,
            'longitude' => $request->longitude,
            'temperature' => $request->temperature,
            'action_type' => 'transit_update',
            'notes' => $notes !== '' ? $notes : 'Transit checkpoint recorded.',
            'signature_path' => $request->signature,
        ]);

        return response()->json(['message' => 'Checkpoint recorded successfully.']);
    }

    private function ensureBatchBelongsToLogistics(Batch $batch, int $userId, bool $allowProcessorHandover): void
    {
        $isAssignedToDriver = (int) $batch->driver_id === $userId;
        $isCurrentHolder = (int) $batch->current_holder_id === $userId;
        $isProcessorHandover = $allowProcessorHandover
            && (int) $batch->current_holder_id === (int) $batch->processor_id;

        abort_unless(
            $isAssignedToDriver || $isCurrentHolder || $isProcessorHandover,
            403,
            'This batch is not available for this logistics account.'
        );
    }
}
