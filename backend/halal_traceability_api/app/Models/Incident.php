<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Incident report for supply chain issues (spoilage, broken seal, delays).
 * Status: Open, Investigating, Resolved.
 */
class Incident extends Model
{
    use HasFactory;

    protected $fillable = [
        'batch_id', 'user_id', 'issue_type',
        'description', 'location', 'status', 'severity',
    ];

    /** User who reported this incident. */
    public function reporter()
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
