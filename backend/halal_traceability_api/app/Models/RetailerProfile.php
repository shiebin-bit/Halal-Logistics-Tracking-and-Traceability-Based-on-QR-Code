<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class RetailerProfile extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'store_name',
        'business_reg_no',
        'outlet_address',
        'store_contact_number'
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}