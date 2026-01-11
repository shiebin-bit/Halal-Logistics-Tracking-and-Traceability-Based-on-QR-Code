<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Batch extends Model
{
    use HasFactory;

    protected $fillable = [
        'batch_id',
        'processor_id',
        'current_holder_id',
        'product_type',
        'weight',
        'slaughter_date',
        'origin_farm',
        'processing_factory',
        'current_location',
        'qr_code_hash',
        'status',
        'freshness_score',
        'halal_status',
        'driver_id',
        'truck_plate',
        'destination_address',
        'estimated_arrival'
    ];

    // Relationship: Who processed this batch?
    public function processor()
    {
        return $this->belongsTo(User::class, 'processor_id');
    }

    // Relationship: Who currently holds this batch?
    public function currentHolder()
    {
        return $this->belongsTo(User::class, 'current_holder_id');
    }

    // Relationship: Assigned Driver
    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    // Relationship: A batch has many checkpoints (history)
    public function checkpoints()
    {
        return $this->hasMany(Checkpoint::class);
    }
}