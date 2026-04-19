<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Batch;
use App\Models\Checkpoint;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class BatchController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $query = $this->visibleBatchesQueryFor($user)->latest('created_at');

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('batch_id', 'LIKE', "%{$search}%")
                    ->orWhere('product_type', 'LIKE', "%{$search}%")
                    ->orWhere('certificate_no', 'LIKE', "%{$search}%");
            });
        }

        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request)
    {
        $user = $request->user();
        $user->ensureBypassAccessState();
        abort_unless($user->role === 'processor', 403, 'Only processors can create batches.');
        abort_if(
            $user->email_verified_at === null && !$user->bypassesEmailVerification(),
            403,
            'Verify your email before creating batches.'
        );
        abort_if(
            !$user->is_approved && !$user->bypassesApprovalChecks(),
            403,
            'Your account is pending admin approval.'
        );

        $request->validate([
            'batch_id' => 'required|string|unique:batches,batch_id',
            'product_type' => 'required|string',
            'weight' => 'required|string',
            'slaughter_date' => 'required|date|before_or_equal:today',
            'processing_date' => 'nullable|date|before_or_equal:today|after_or_equal:slaughter_date',
            'origin_farm' => 'required|string',
            'processing_factory' => 'required|string',
            'current_location' => 'required|string',
            'certificate_authority' => 'nullable|string',
            'certificate_no' => 'nullable|string',
            'certificate_valid_until' => 'nullable|date',
            'certificate_document' => 'nullable|file|mimes:pdf,jpg,jpeg,png|max:5120',
            'destination_address' => 'nullable|string',
            'estimated_arrival' => 'nullable|date',
            'generate_qr' => 'nullable|boolean',
        ]);

        $certificate = $this->resolveCertificateSnapshot($request, $user);

        $batch = DB::transaction(function () use ($request, $user, $certificate) {
            $batch = Batch::create([
                'batch_id' => $request->batch_id,
                'processor_id' => $user->id,
                'current_holder_id' => $user->id,
                'product_type' => $request->product_type,
                'weight' => $request->weight,
                'slaughter_date' => $request->slaughter_date,
                'processing_date' => $request->processing_date ?? $request->slaughter_date,
                'origin_farm' => $request->origin_farm,
                'processing_factory' => $request->processing_factory,
                'current_location' => $request->current_location,
                'certificate_authority' => $certificate['authority'],
                'certificate_no' => $certificate['number'],
                'certificate_valid_until' => $certificate['valid_until'],
                'certificate_document_path' => $certificate['document_path'],
                'destination_address' => $request->destination_address,
                'estimated_arrival' => $request->estimated_arrival,
                'status' => 'Ready for QR Generation',
            ]);

            Checkpoint::create([
                'batch_id' => $batch->id,
                'user_id' => $user->id,
                'location_name' => $request->current_location,
                'action_type' => 'batch_created',
                'temperature' => 0,
                'notes' => 'Batch created in system.',
            ]);

            return $batch;
        });

        if ($request->boolean('generate_qr') || $request->filled('qr_code_hash')) {
            $this->generateQrForBatch($batch, $user->role === 'admin');
            $batch->refresh();
        }

        return response()->json([
            'message' => 'Batch created successfully.',
            'data' => $batch->fresh(),
        ], 201);
    }

    public function generateQr(Request $request, $id)
    {
        $user = $request->user();
        $batch = $this->visibleBatchesQueryFor($user)->findOrFail($id);

        abort_unless(
            $user->role === 'admin' || ((int) $batch->processor_id === (int) $user->id && $user->role === 'processor'),
            403,
            'You are not allowed to generate a QR code for this batch.'
        );

        $this->generateQrForBatch($batch, $user->role === 'admin');

        return response()->json([
            'message' => 'QR code generated successfully.',
            'data' => $batch->fresh(),
        ]);
    }

    public function updateStatus(Request $request)
    {
        $user = $request->user();

        $request->validate([
            'batch_id' => 'required|exists:batches,batch_id',
            'status' => 'required|string',
        ]);

        $batch = $this->visibleBatchesQueryFor($user)
            ->where('batch_id', $request->batch_id)
            ->firstOrFail();

        abort_unless(
            $user->role === 'processor' && (int) $batch->processor_id === (int) $user->id,
            403,
            'Only the owning processor can update batch status.'
        );

        $status = $request->status === 'Ready' ? 'Ready for QR Generation' : $request->status;
        $allowedTransitions = [
            'Pending Documentation' => ['Ready for QR Generation'],
            'Processing' => ['Ready for QR Generation'],
            'Ready for QR Generation' => [],
            'QR Generated' => [],
            'In Transit' => [],
            'Delivered' => [],
            'Rejected' => [],
        ];

        $current = $batch->status;
        abort_unless(
            in_array($status, $allowedTransitions[$current] ?? [], true),
            422,
            'This batch status transition is not allowed.'
        );

        DB::transaction(function () use ($batch, $status) {
            $batch->status = $status;
            $batch->save();

            Checkpoint::create([
                'batch_id' => $batch->id,
                'user_id' => Auth::id(),
                'location_name' => $batch->current_location,
                'action_type' => 'status_update',
                'temperature' => 0,
                'notes' => "Status updated to {$status}.",
            ]);
        });

        return response()->json(['message' => 'Status updated successfully.']);
    }

    public function publicIndex(Request $request)
    {
        $query = Batch::query()
            ->whereNotNull('qr_code_hash')
            ->whereNull('qr_revoked_at')
            ->where('status', '!=', 'Invalid - Certificate Revoked')
            ->latest('created_at');

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('batch_id', 'LIKE', "%{$search}%")
                    ->orWhere('product_type', 'LIKE', "%{$search}%")
                    ->orWhere('certificate_no', 'LIKE', "%{$search}%");
            });
        }

        $query->select([
            'id',
            'batch_id',
            'product_type',
            'weight',
            'origin_farm',
            'processing_factory',
            'slaughter_date',
            'processing_date',
            'status',
            'halal_status',
            'freshness_score',
            'certificate_authority',
            'certificate_no',
            'certificate_valid_until',
        ]);

        return response()->json($query->paginate(10));
    }

    public function publicShow(string $batchId)
    {
        $batch = Batch::with([
            'checkpoints' => fn ($q) => $q->orderBy('created_at'),
        ])->where('batch_id', $batchId)->firstOrFail();

        if (!$batch->hasActiveQr()) {
            return response()->json([
                'message' => 'This batch is not available for public verification.',
                'code' => 'BATCH_NOT_PUBLIC',
            ], 422);
        }

        return response()->json([
            'batch' => [
                'id' => $batch->id,
                'batch_id' => $batch->batch_id,
                'product_type' => $batch->product_type,
                'weight' => $batch->weight,
                'origin_farm' => $batch->origin_farm,
                'processing_factory' => $batch->processing_factory,
                'slaughter_date' => $batch->slaughter_date,
                'processing_date' => $batch->processing_date,
                'status' => $batch->status,
                'halal_status' => $batch->halal_status,
                'freshness_score' => $batch->freshness_score,
                'certificate_authority' => $batch->certificate_authority,
                'certificate_no' => $batch->certificate_no,
                'certificate_valid_until' => $batch->certificate_valid_until,
                'certificate_active' => $batch->hasValidCertificate(),
                'qr_code_payload' => $this->publicQrPayload($batch),
                'checkpoints' => $batch->checkpoints
                    ->map(fn (Checkpoint $checkpoint) => $this->publicCheckpointItem($checkpoint))
                    ->values(),
            ],
        ]);
    }

    public function show(Request $request, $id)
    {
        $batch = $this->visibleBatchesQueryFor($request->user())
            ->with([
                'checkpoints' => fn ($q) => $q->orderBy('created_at'),
                'currentHolder',
                'processor',
            ])
            ->findOrFail($id);

        return response()->json(['batch' => $batch]);
    }

    private function visibleBatchesQueryFor(User $user): Builder
    {
        $query = Batch::query();

        if ($user->role === 'admin') {
            return $query;
        }

        if ($user->role === 'processor') {
            return $query->where('processor_id', $user->id);
        }

        if ($user->role === 'logistics') {
            return $query->where(function ($q) use ($user) {
                $q->where('driver_id', $user->id)
                    ->orWhere('current_holder_id', $user->id);
            });
        }

        if ($user->role === 'retailer') {
            return $query->where('current_holder_id', $user->id);
        }

        return $query->whereRaw('1 = 0');
    }

    private function resolveCertificateSnapshot(Request $request, User $user): array
    {
        $processorProfile = $user->processorProfile;
        $authority = trim((string) ($request->certificate_authority ?: 'Processor Provided'));
        $number = trim((string) ($request->certificate_no ?: $processorProfile?->halal_cert_no));
        $validUntil = $request->certificate_valid_until ?: $processorProfile?->halal_expiry_date;
        $documentPath = $request->hasFile('certificate_document')
            ? $request->file('certificate_document')->store('batch-certificates', 'public')
            : $processorProfile?->cert_document_path;

        abort_if($number === '', 422, 'A valid halal certificate number is required.');
        abort_if(!$validUntil, 422, 'A halal certificate expiry date is required.');
        abort_if(!$documentPath, 422, 'A halal certificate document is required before batch creation.');

        $expiryDate = Carbon::parse($validUntil);
        abort_if($expiryDate->isPast(), 422, 'The halal certificate is expired and cannot be used.');

        return [
            'authority' => $authority === '' ? 'Processor Provided' : $authority,
            'number' => $number,
            'valid_until' => $expiryDate->toDateString(),
            'document_path' => $documentPath,
        ];
    }

    private function generateQrForBatch(Batch $batch, bool $allowRegeneration): void
    {
        abort_if(!$batch->hasValidCertificate(), 422, 'A valid halal certificate is required before QR generation.');
        abort_if(
            !$allowRegeneration && $batch->hasActiveQr(),
            409,
            'This batch already has an active QR code.'
        );
        abort_if(
            in_array($batch->status, ['Delivered', 'Rejected', 'Invalid - Certificate Revoked'], true),
            422,
            'QR generation is not allowed for the current batch status.'
        );

        $issuedAt = now();
        $signature = hash_hmac(
            'sha256',
            implode('|', [$batch->batch_id, $batch->certificate_no, $issuedAt->toIso8601String()]),
            (string) config('app.key')
        );
        $payload = "BATCH:{$batch->batch_id}|SIG:{$signature}";

        DB::transaction(function () use ($batch, $signature, $payload, $issuedAt) {
            $batch->forceFill([
                'qr_code_hash' => $signature,
                'qr_code_payload' => $payload,
                'qr_generated_at' => $issuedAt,
                'qr_revoked_at' => null,
                'status' => 'QR Generated',
            ])->save();

            Checkpoint::create([
                'batch_id' => $batch->id,
                'user_id' => Auth::id() ?? $batch->processor_id,
                'location_name' => $batch->current_location,
                'action_type' => 'qr_generated',
                'temperature' => 0,
                'notes' => 'Secure QR code generated.',
            ]);
        });
    }

    private function publicCheckpointItem(Checkpoint $checkpoint): array
    {
        $actionType = (string) $checkpoint->action_type;
        $isIncident = $actionType === 'incident'
            || str_contains((string) $checkpoint->notes, '[INCIDENT:');
        $hasTemperatureAlert = $checkpoint->temperature < 0 || $checkpoint->temperature > 4;

        return [
            'id' => $checkpoint->id,
            'location_name' => $checkpoint->location_name,
            'latitude' => $checkpoint->latitude,
            'longitude' => $checkpoint->longitude,
            'temperature' => $checkpoint->temperature,
            'action_type' => $actionType,
            'created_at' => $checkpoint->created_at,
            'alert' => $isIncident || $hasTemperatureAlert,
            'summary' => match (true) {
                $isIncident => 'Incident recorded',
                $actionType === 'arrival' => 'Arrival recorded',
                $actionType === 'handover' => 'Custody transferred',
                $actionType === 'qr_generated' => 'Batch released for traceability',
                default => 'Transit update',
            },
        ];
    }

    private function publicQrPayload(Batch $batch): ?string
    {
        if (filled($batch->qr_code_payload)) {
            return $batch->qr_code_payload;
        }

        if (!filled($batch->qr_code_hash)) {
            return null;
        }

        return "BATCH:{$batch->batch_id}|SIG:{$batch->qr_code_hash}";
    }
}
