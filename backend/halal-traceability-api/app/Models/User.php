<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'phone_number',
        'profile_image',
        'is_approved'
    ];

    // --- Profile Relationships ---
    public function processorProfile()
    {
        return $this->hasOne(ProcessorProfile::class);
    }

    public function logisticsProfile()
    {
        return $this->hasOne(LogisticsProfile::class);
    }


    public function retailerProfile()
    {
        return $this->hasOne(RetailerProfile::class);
    }

    // --- Batch Relationships ---
    // Batches currently held by this user
    public function batches()
    {
        return $this->hasMany(Batch::class, 'current_holder_id');
    }
}