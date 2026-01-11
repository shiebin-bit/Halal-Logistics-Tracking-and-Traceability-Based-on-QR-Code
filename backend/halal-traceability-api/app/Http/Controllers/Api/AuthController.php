<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;

class AuthController extends Controller
{
    // POST /api/register
    public function register(Request $request)
    {
        // 1. Validate Common Fields
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:6',
            'role' => 'required|in:processor,logistics,retailer,consumer',
            'phone_number' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json($validator->errors(), 400);
        }

        // 2. Create Base User
        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'role' => $request->role,
            'phone_number' => $request->phone_number,
            'is_approved' => true, // Auto-approve for now (or set to false if you want admin approval)
        ]);

        // 3. Create Specific Profile based on Role
        if ($request->role === 'logistics') {
            // Validate Logistics Fields
            $request->validate([
                'vehicle_plate_no' => 'required|string',
                'driver_license_no' => 'required|string',
                'vehicle_type' => 'required|string',
            ]);

            $user->logisticsProfile()->create([
                'vehicle_plate_no' => $request->vehicle_plate_no,
                'driver_license_no' => $request->driver_license_no,
                'vehicle_type' => $request->vehicle_type,
            ]);
        } elseif ($request->role === 'processor') {
            // Validate Processor Fields
            $request->validate([
                'company_reg_no' => 'required|string',
                'halal_cert_no' => 'required|string',
                'halal_expiry_date' => 'required|date',
                'factory_address' => 'required|string',
            ]);

            $user->processorProfile()->create([
                'company_reg_no' => $request->company_reg_no,
                'halal_cert_no' => $request->halal_cert_no,
                'halal_expiry_date' => $request->halal_expiry_date,
                'factory_address' => $request->factory_address,
            ]);
        } elseif ($request->role === 'retailer') {
            // Validate Retailer Fields
            $request->validate([
                'store_name' => 'required|string',
                'business_reg_no' => 'required|string',
                'outlet_address' => 'required|string',
            ]);

            $user->retailerProfile()->create([
                'store_name' => $request->store_name,
                'business_reg_no' => $request->business_reg_no,
                'outlet_address' => $request->outlet_address,
            ]);
        }

        // 4. Generate Token
        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'message' => 'User registered successfully',
            'user' => $user->load('logisticsProfile', 'processorProfile', 'retailerProfile'),
            'token' => $token
        ], 201);
    }

    // POST /api/login
    public function login(Request $request)
    {
        if (!Auth::attempt($request->only('email', 'password'))) {
            return response()->json(['message' => 'Invalid login details'], 401);
        }

        $user = User::where('email', $request->email)->firstOrFail();

        // Load the profile data before returning
        if ($user->role === 'logistics') {
            $user->load('logisticsProfile');
        } elseif ($user->role === 'processor') {
            $user->load('processorProfile');
        } elseif ($user->role === 'retailer') {
            $user->load('retailerProfile');
        }

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'message' => 'Login success',
            'user' => $user,
            'token' => $token,
        ]);
    }
}