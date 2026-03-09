<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

/**
 * User model with role-based profile relationships.
 * Roles: admin, processor, logistics, retailer, consumer.
 */
class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name', 'email', 'password', 'role',
        'phone_number', 'profile_image', 'is_approved'
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'password' => 'hashed',
        'is_approved' => 'boolean',
    ];

    /** Processor profile relation for users with `processor` role. */
    public function processorProfile()
    {
        return $this->hasOne(ProcessorProfile::class);
    }

    /** Logistics profile relation for users with `logistics` role. */
    public function logisticsProfile()
    {
        return $this->hasOne(LogisticsProfile::class);
    }

    /** Retailer profile relation for users with `retailer` role. */
    public function retailerProfile()
    {
        return $this->hasOne(RetailerProfile::class);
    }

    /** Batches currently held by this user. */
    public function batches()
    {
        return $this->hasMany(Batch::class, 'current_holder_id');
    }
}
