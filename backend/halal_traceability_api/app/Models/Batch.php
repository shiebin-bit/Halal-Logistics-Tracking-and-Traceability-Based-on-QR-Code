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
        'product_type', 'weight', 'slaughter_date',
        'origin_farm', 'processing_factory', 'current_location',
        'qr_code_hash', 'status', 'freshness_score', 'halal_status',
        'driver_id', 'truck_plate', 'destination_address', 'estimated_arrival'
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
}
