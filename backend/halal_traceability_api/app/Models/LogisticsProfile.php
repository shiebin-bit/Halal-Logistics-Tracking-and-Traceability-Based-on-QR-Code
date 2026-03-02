<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class LogisticsProfile extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'vehicle_plate_no',
        'driver_license_no',
        'vehicle_type',
        'gdl_license_path'
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}