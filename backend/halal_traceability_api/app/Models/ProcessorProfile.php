<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Stores processor-specific registration and halal certificate details.
 */
class ProcessorProfile extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'company_reg_no',
        'halal_cert_no',
        'halal_expiry_date',
        'factory_address',
        'cert_document_path'
    ];

    /** Get the owning user account for this processor profile. */
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
