<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Represents a halal product batch in the supply chain.
 * Tracks ownership, status, and location from processor to retailer.
 */
class Batch extends Model
{
    use HasFactory;

    protected $fillable = [
        'batch_id', 'processor_id', 'current_holder_id',
        'product_type', 'weight', 'slaughter_date', 'processing_date',
        'origin_farm', 'processing_factory', 'current_location',
        'certificate_authority', 'certificate_no', 'certificate_valid_until',
        'certificate_document_path',
        'qr_code_hash', 'qr_code_payload', 'qr_generated_at', 'qr_revoked_at',
        'status', 'freshness_score', 'halal_status',
        'driver_id', 'truck_plate', 'destination_address', 'estimated_arrival'
    ];

    protected $casts = [
        'slaughter_date' => 'date',
        'processing_date' => 'date',
        'certificate_valid_until' => 'date',
        'qr_generated_at' => 'datetime',
        'qr_revoked_at' => 'datetime',
        'estimated_arrival' => 'datetime',
    ];

    /** User who originally created/processed this batch. */
    public function processor()
    {
        return $this->belongsTo(User::class, 'processor_id');
    }

    /** User currently responsible for this batch. */
    public function currentHolder()
    {
        return $this->belongsTo(User::class, 'current_holder_id');
    }

    /** Assigned logistics driver for the current shipment leg. */
    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    /** Chronological traceability checkpoints for this batch. */
    public function checkpoints()
    {
        return $this->hasMany(Checkpoint::class);
    }

    public function incidents()
    {
        return $this->hasMany(Incident::class, 'batch_id', 'batch_id');
    }

    public function hasValidCertificate(): bool
    {
        return filled($this->certificate_no)
            && filled($this->certificate_authority)
            && filled($this->certificate_document_path)
            && $this->certificate_valid_until !== null
            && !$this->certificate_valid_until->isBefore(today());
    }

    public function hasActiveQr(): bool
    {
        return filled($this->qr_code_hash)
            && $this->qr_revoked_at === null
            && $this->status !== 'Invalid - Certificate Revoked';
    }
}
