<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

/**
 * Handles user profile updates including name, avatar, and role-specific fields.
 */
class UserUpdateController extends Controller
{
    /**
     * Update the authenticated user's profile.
     * Handles avatar upload with old image cleanup, and role-specific profile data.
     */
    public function update(Request $request)
    {
        $user = Auth::user();

        // Update base user info
        $user->update($request->only(['name', 'phone']));

        // Handle profile image upload (delete old image if exists)
        if ($request->hasFile('profile_image')) {
            if ($user->profile_image) {
                Storage::disk('public')->delete($user->profile_image);
            }
            $path = $request->file('profile_image')->store('avatars', 'public');
            $user->profile_image = $path;
            $user->save();
        }

        // Update role-specific profile using updateOrCreate for safety
        if ($user->role === 'logistics') {
            $user->logisticsProfile()->updateOrCreate(
                ['user_id' => $user->id],
                [
                    'vehicle_plate_no' => $request->vehicle_plate_no,
                    'vehicle_type' => $request->vehicle_type,
                    'driver_license_no' => $request->driver_license_no
                ]
            );
        } elseif ($user->role === 'processor') {
            $user->processorProfile()->updateOrCreate(
                ['user_id' => $user->id],
                [
                    'company_reg_no' => $request->company_reg_no,
                    'halal_cert_no' => $request->halal_cert_no,
                    'factory_address' => $request->factory_address
                ]
            );
        } elseif ($user->role === 'retailer') {
            $user->retailerProfile()->updateOrCreate(
                ['user_id' => $user->id],
                [
                    'store_name' => $request->store_name,
                    'outlet_address' => $request->outlet_address,
                    'business_reg_no' => $request->business_reg_no
                ]
            );
        }

        // Reload fresh data with profile relation
        $user->refresh();
        if ($user->role === 'logistics') $user->load('logisticsProfile');
        if ($user->role === 'processor') $user->load('processorProfile');
        if ($user->role === 'retailer') $user->load('retailerProfile');

        return response()->json([
            'message' => 'Profile updated successfully',
            'user' => $user
        ]);
    }
}