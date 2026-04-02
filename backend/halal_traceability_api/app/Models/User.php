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
        'phone_number', 'profile_image', 'is_approved', 'approved_at',
        'email_verification_code', 'email_verification_expires_at',
        'registration_status',
    ];

    protected $hidden = [
        'password',
        'remember_token',
        'email_verification_code',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'password' => 'hashed',
        'is_approved' => 'boolean',
        'approved_at' => 'datetime',
        'email_verification_expires_at' => 'datetime',
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

    public function isDemoAccessAccount(): bool
    {
        $email = strtolower((string) $this->email);
        $configuredEmails = config('services.demo_access.emails', []);

        return in_array($email, $configuredEmails, true);
    }

    public function bypassesEmailVerification(): bool
    {
        return $this->role === 'admin' || $this->isDemoAccessAccount();
    }

    public function bypassesApprovalChecks(): bool
    {
        return $this->isDemoAccessAccount();
    }

    public function ensureBypassAccessState(): void
    {
        if (!$this->bypassesEmailVerification() && !$this->bypassesApprovalChecks()) {
            return;
        }

        if ($this->bypassesEmailVerification() && $this->email_verified_at === null) {
            $this->email_verified_at = now();
            $this->email_verification_code = null;
            $this->email_verification_expires_at = null;
        }

        if ($this->bypassesApprovalChecks()) {
            $this->is_approved = true;
            $this->approved_at ??= now();
            $this->registration_status = 'approved';
        } elseif ($this->role === 'admin' && $this->is_approved) {
            $this->registration_status = 'approved';
            $this->approved_at ??= now();
        }

        if ($this->isDirty()) {
            $this->save();
        }
    }

    public function getProfileImageAttribute($value)
    {
        return $this->normalizeProfileImagePath($value);
    }

    public function setProfileImageAttribute($value): void
    {
        $this->attributes['profile_image'] = $this->normalizeProfileImagePath($value);
    }

    private function normalizeProfileImagePath($value): ?string
    {
        if (!is_string($value)) {
            return null;
        }

        $normalized = trim(str_replace('\\', '/', $value));
        if ($normalized === '') {
            return null;
        }

        $path = parse_url($normalized, PHP_URL_PATH);
        if (is_string($path) && $path !== '') {
            $normalized = $path;
        }

        $normalized = ltrim($normalized, '/');

        if (str_starts_with($normalized, 'public/')) {
            $normalized = substr($normalized, strlen('public/'));
        }

        if (str_starts_with($normalized, 'storage/')) {
            $normalized = substr($normalized, strlen('storage/'));
        }

        return $normalized !== '' ? $normalized : null;
    }
}
