<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Checkpoint extends Model
{
    use HasFactory;

    protected $fillable = [
        'batch_id',
        'user_id',
        'location_name',
        'latitude',
        'longitude',
        'temperature',
        'action_type',
        'notes',
        'signature_path'
    ];

    public function batch()
    {
        return $this->belongsTo(Batch::class);
    }

    public function user() // The driver/person who scanned
    {
        return $this->belongsTo(User::class);
    }
}