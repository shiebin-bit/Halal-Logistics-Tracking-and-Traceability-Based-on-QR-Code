<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

class UserUpdateController extends Controller
{
    // POST /api/user/update
    public function update(Request $request)
    {
        $user = Auth::user(); // Get current logged in user

        // 1. Validate Common Fields
        $request->validate([
            'name' => 'nullable|string|max:255',
            'phone' => 'nullable|string|max:20',
            'profile_image' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:2048',
        ]);

        // 2. Update Base User Table
        if ($request->has('name')) {
            $user->name = $request->name;
        }
        if ($request->has('phone')) {
            $user->phone_number = $request->phone;
        }

        // 3. Handle Profile Image Upload
        if ($request->hasFile('profile_image')) {
            // Delete old image if exists
            if ($user->profile_image) {
                Storage::disk('public')->delete($user->profile_image);
            }
            // Store new image
            $path = $request->file('profile_image')->store('avatars', 'public');
            $user->profile_image = $path;
        }

        // 4. Update Role-Specific Profile Tables
        if ($user->role === 'logistics' && $user->logisticsProfile) {
            $user->logisticsProfile->update($request->only([
                'vehicle_plate_no',
                'vehicle_type',
                'driver_license_no'
            ]));
        } elseif ($user->role === 'processor' && $user->processorProfile) {
            $user->processorProfile->update($request->only([
                'company_reg_no',
                'halal_cert_no',
                'factory_address'
            ]));
        } elseif ($user->role === 'retailer' && $user->retailerProfile) {
            $user->retailerProfile->update($request->only([
                'store_name',
                'outlet_address',
                'store_contact_number'
            ]));
        }

        // Save base user changes
        /** @var \App\Models\User $user */
        $user->save();

        // Reload data to return fresh info
        $user->refresh();
        if ($user->role === 'logistics')
            $user->load('logisticsProfile');
        if ($user->role === 'processor')
            $user->load('processorProfile');
        if ($user->role === 'retailer')
            $user->load('retailerProfile');

        return response()->json([
            'message' => 'Profile updated successfully',
            'user' => $user
        ]);
    }
}