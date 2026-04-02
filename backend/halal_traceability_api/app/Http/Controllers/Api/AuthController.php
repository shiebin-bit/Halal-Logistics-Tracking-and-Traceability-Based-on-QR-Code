<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\Validator;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        if (!$request->hasFile('document') && $request->hasFile('profile_image')) {
            $request->files->set('document', $request->file('profile_image'));
        }

        $requiresApproval = in_array($request->role, ['processor', 'logistics', 'retailer'], true);

        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => ['required', 'string', 'min:8', 'regex:/[A-Z]/', 'regex:/[a-z]/', 'regex:/[0-9]/'],
            'role' => 'required|in:processor,logistics,retailer,consumer',
            'phone_number' => 'required|string|unique:users,phone_number',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed.',
                'errors' => $validator->errors(),
            ], 422);
        }

        if ($request->role === 'logistics') {
            $request->validate([
                'vehicle_plate_no' => 'required|string',
                'driver_license_no' => 'required|string',
                'vehicle_type' => 'required|string',
                'document' => 'required|file|mimes:pdf,jpg,jpeg,png|max:5120',
            ]);
        } elseif ($request->role === 'processor') {
            $request->validate([
                'company_reg_no' => 'required|string',
                'halal_cert_no' => 'required|string',
                'halal_expiry_date' => 'required|date|after_or_equal:today',
                'factory_address' => 'required|string',
                'document' => 'required|file|mimes:pdf,jpg,jpeg,png|max:5120',
            ]);
        } elseif ($request->role === 'retailer') {
            $request->validate([
                'store_name' => 'required|string',
                'business_reg_no' => 'required|string',
                'outlet_address' => 'required|string',
            ]);
        }

        $verificationCode = $this->generateVerificationCode();

        $user = DB::transaction(function () use ($request, $requiresApproval, $verificationCode) {
            $documentPath = $request->hasFile('document')
                ? $request->file('document')->store('verification-documents/'.$request->role, 'public')
                : null;

            $user = User::create([
                'name' => $request->name,
                'email' => $request->email,
                'password' => Hash::make($request->password),
                'role' => $request->role,
                'phone_number' => $request->phone_number,
                'is_approved' => !$requiresApproval,
                'approved_at' => $requiresApproval ? null : Carbon::now(),
                'registration_status' => $requiresApproval ? 'pending' : 'approved',
                'email_verification_code' => $verificationCode,
                'email_verification_expires_at' => now()->addMinutes((int) config('services.email_verification.expires_minutes', 15)),
            ]);

            if ($request->role === 'logistics') {
                $user->logisticsProfile()->create([
                    'vehicle_plate_no' => $request->vehicle_plate_no,
                    'driver_license_no' => $request->driver_license_no,
                    'vehicle_type' => $request->vehicle_type,
                    'gdl_license_path' => $documentPath,
                ]);
            } elseif ($request->role === 'processor') {
                $user->processorProfile()->create([
                    'company_reg_no' => $request->company_reg_no,
                    'halal_cert_no' => $request->halal_cert_no,
                    'halal_expiry_date' => $request->halal_expiry_date,
                    'factory_address' => $request->factory_address,
                    'cert_document_path' => $documentPath,
                ]);
            } elseif ($request->role === 'retailer') {
                $user->retailerProfile()->create([
                    'store_name' => $request->store_name,
                    'business_reg_no' => $request->business_reg_no,
                    'outlet_address' => $request->outlet_address,
                ]);
            }

            return $user;
        });

        [$emailDispatched, $debugCode] = $this->dispatchVerificationCode($user, $verificationCode);

        $user->load('logisticsProfile', 'processorProfile', 'retailerProfile');

        return response()->json([
            'message' => $emailDispatched
                ? 'Registration submitted. Verify your email to continue.'
                : 'Registration submitted. Email delivery is unavailable, so use the verification code shown for local testing.',
            'user' => $user,
            'requires_approval' => $requiresApproval,
            'email_verification_required' => true,
            'verification_delivery' => $emailDispatched ? 'email' : 'debug',
            'verification_code_debug' => $debugCode,
        ], 201);
    }

    public function verifyEmailCode(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'code' => 'required|string|size:6',
        ]);

        $user = User::where('email', $request->email)->first();

        if (
            !$user
            || $user->email_verification_code !== $request->code
            || $user->email_verification_expires_at === null
            || $user->email_verification_expires_at->isPast()
        ) {
            return response()->json([
                'message' => 'The email verification code is invalid or expired.',
            ], 422);
        }

        $user->forceFill([
            'email_verified_at' => now(),
            'email_verification_code' => null,
            'email_verification_expires_at' => null,
        ])->save();

        $response = [
            'message' => $user->is_approved
                ? 'Email verified successfully.'
                : 'Email verified successfully. Your account is still pending admin approval.',
            'requires_approval' => !$user->is_approved,
        ];

        if ($user->is_approved) {
            $response['token'] = $user->createToken('auth_token')->plainTextToken;
            $response['user'] = $user->fresh()->load('logisticsProfile', 'processorProfile', 'retailerProfile');
        }

        return response()->json($response);
    }

    public function resendEmailCode(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
        ]);

        $user = User::where('email', $request->email)->first();

        if ($user === null) {
            return response()->json([
                'message' => 'If the email exists, a new verification code has been issued.',
            ]);
        }

        if ($user->email_verified_at !== null) {
            return response()->json([
                'message' => 'This email address is already verified.',
            ]);
        }

        $verificationCode = $this->generateVerificationCode();
        $user->forceFill([
            'email_verification_code' => $verificationCode,
            'email_verification_expires_at' => now()->addMinutes((int) config('services.email_verification.expires_minutes', 15)),
        ])->save();

        [$emailDispatched, $debugCode] = $this->dispatchVerificationCode($user, $verificationCode);

        return response()->json([
            'message' => $emailDispatched
                ? 'A new verification code has been sent.'
                : 'Email delivery is unavailable, so use the debug code for local testing.',
            'verification_delivery' => $emailDispatched ? 'email' : 'debug',
            'verification_code_debug' => $debugCode,
        ]);
    }

    public function login(Request $request)
    {
        if (!Auth::attempt($request->only('email', 'password'))) {
            return response()->json(['message' => 'Invalid login details'], 401);
        }

        $user = User::where('email', $request->email)->firstOrFail();
        $user->ensureBypassAccessState();

        if ($user->email_verified_at === null && !$user->bypassesEmailVerification()) {
            Auth::logout();

            return response()->json([
                'message' => 'Please verify your email before signing in.',
            ], 403);
        }

        if ($user->registration_status === 'rejected' && !$user->bypassesApprovalChecks()) {
            Auth::logout();

            return response()->json([
                'message' => 'Your registration was rejected. Please contact admin.',
            ], 403);
        }

        if (!$user->is_approved && !$user->bypassesApprovalChecks()) {
            Auth::logout();

            return response()->json([
                'message' => 'Your account is pending approval by admin.',
            ], 403);
        }

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

    public function forgotPassword(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
        ]);

        try {
            $status = Password::sendResetLink(
                $request->only('email')
            );

            if (
                $status === Password::RESET_LINK_SENT ||
                $status === Password::INVALID_USER
            ) {
                return response()->json([
                    'message' => 'If the email exists, a reset link has been sent.'
                ]);
            }

            Log::warning('Password reset request failed', [
                'email' => $request->email,
                'status' => $status,
            ]);
        } catch (\Throwable $e) {
            Log::error('Password reset exception', [
                'email' => $request->email,
                'error' => $e->getMessage(),
            ]);
        }

        return response()->json([
            'message' => 'Unable to send reset link right now. Please contact admin.'
        ], 500);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json(['message' => 'Logged out successfully']);
    }

    private function generateVerificationCode(): string
    {
        return str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    }

    private function dispatchVerificationCode(User $user, string $code): array
    {
        $debugCode = null;
        $emailDispatched = false;
        $mailer = (string) config('mail.default');

        try {
            Mail::raw(
                "Your HalalTrack verification code is {$code}. It expires in ".config('services.email_verification.expires_minutes', 15)." minutes.",
                function ($message) use ($user): void {
                    $message
                        ->to($user->email, $user->name)
                        ->subject('HalalTrack Email Verification');
                }
            );

            $emailDispatched = !in_array($mailer, ['array', 'log'], true);
        } catch (\Throwable $e) {
            Log::warning('Email verification dispatch failed', [
                'email' => $user->email,
                'error' => $e->getMessage(),
            ]);
        }

        if (
            !$emailDispatched
            && config('services.email_verification.debug_expose_code')
            && app()->environment(['local', 'testing'])
        ) {
            $debugCode = $code;
        }

        return [$emailDispatched, $debugCode];
    }
}
