<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Audit trail entry for batch tracking.
 * Records location, temperature, and actions at each stage of the supply chain.
 */
class Checkpoint extends Model
{
    use HasFactory;

    protected $fillable = [
        'batch_id', 'user_id', 'location_name',
        'latitude', 'longitude', 'temperature',
        'action_type', 'notes', 'signature_path'
    ];

    /** Batch referenced by this checkpoint entry. */
    public function batch()
    {
        return $this->belongsTo(Batch::class);
    }

    /** User who submitted this checkpoint event. */
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
