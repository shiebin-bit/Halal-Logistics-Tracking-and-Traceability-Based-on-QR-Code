<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Batch;
use App\Models\Checkpoint;
use App\Models\Incident;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Carbon;
use Illuminate\Http\Request;

/**
 * Admin-only controller for managing users, viewing stats, and monitoring incidents.
 * Each method checks admin role before executing.
 */
class AdminController extends Controller
{
    /** Get dashboard statistics (total batches, pending users, active incidents). */
    public function getStats(Request $request)
    {
        $today = now()->startOfDay();
        $expiringSoon = now()->addDays(14)->endOfDay();

        return response()->json([
            'total_batches' => Batch::count(),
            'pending_users' => User::query()
                ->where(function ($query) {
                    $query->where('registration_status', 'pending')
                        ->orWhere(function ($legacy) {
                            $legacy->whereNull('registration_status')
                                ->where('is_approved', 0);
                        });
                })
                ->count(),
            'active_issues' => Incident::where('status', '!=', 'Resolved')->count(),
            'status_breakdown' => [
                'ready_for_qr' => Batch::where('status', 'Ready for QR Generation')->count(),
                'qr_generated' => Batch::where('status', 'QR Generated')->count(),
                'in_transit' => Batch::where('status', 'In Transit')->count(),
                'delivered' => Batch::where('status', 'Delivered')->count(),
                'rejected' => Batch::where('status', 'Rejected')->count(),
                'revoked' => Batch::where('status', 'Invalid - Certificate Revoked')->count(),
            ],
            'certificate_summary' => [
                'active' => Batch::query()
                    ->whereNotNull('certificate_no')
                    ->whereNotNull('certificate_authority')
                    ->whereNotNull('certificate_document_path')
                    ->whereDate('certificate_valid_until', '>=', $today)
                    ->whereNull('qr_revoked_at')
                    ->count(),
                'expiring_soon' => Batch::query()
                    ->whereNotNull('certificate_no')
                    ->whereNotNull('certificate_valid_until')
                    ->whereBetween('certificate_valid_until', [$today, $expiringSoon])
                    ->whereNull('qr_revoked_at')
                    ->count(),
                'expired' => Batch::query()
                    ->whereNotNull('certificate_valid_until')
                    ->whereDate('certificate_valid_until', '<', $today)
                    ->count(),
                'revoked' => Batch::query()
                    ->whereNotNull('qr_revoked_at')
                    ->count(),
            ],
        ]);
    }

    /** List users, optionally filtered by approval status. */
    public function getUsers(Request $request)
    {
        $query = User::with(['processorProfile', 'logisticsProfile', 'retailerProfile']);
        $status = $request->query('status');

        if ($status === 'pending') {
            $query->where(function ($pending) {
                $pending->where('registration_status', 'pending')
                    ->orWhere(function ($legacy) {
                        $legacy->whereNull('registration_status')
                            ->where('is_approved', 0);
                    });
            });
        } elseif (in_array($status, ['approved', 'rejected'], true)) {
            $query->where('registration_status', $status);
        }

        return response()->json([
            'data' => $query->latest('created_at')->get(),
        ]);
    }

    /** Approve a pending user registration. */
    public function approveUser($id)
    {
        $user = User::findOrFail($id);
        $user->is_approved = 1;
        $user->approved_at = Carbon::now();
        $user->registration_status = 'approved';
        $user->save();
        return response()->json(['message' => 'User Approved']);
    }

    /** Reject a pending user registration without deleting audit history. */
    public function rejectUser($id)
    {
        $user = User::findOrFail($id);
        $user->is_approved = 0;
        $user->approved_at = null;
        $user->registration_status = 'rejected';
        $user->save();

        return response()->json(['message' => 'User Rejected']);
    }

    /** List all incidents, newest first. */
    public function getIncidents()
    {
        return response()->json(['data' => Incident::orderBy('created_at', 'desc')->get()]);
    }

    public function revokeBatchCertificate($id, Request $request)
    {
        $batch = Batch::findOrFail($id);

        DB::transaction(function () use ($batch, $request) {
            $batch->forceFill([
                'qr_revoked_at' => now(),
                'status' => 'Invalid - Certificate Revoked',
                'halal_status' => 'breached',
            ])->save();

            Checkpoint::create([
                'batch_id' => $batch->id,
                'user_id' => $request->user()->id,
                'location_name' => $batch->current_location,
                'temperature' => 0,
                'action_type' => 'transit_update',
                'notes' => 'Certificate revoked by administrator.',
            ]);
        });

        return response()->json([
            'message' => 'Batch certificate revoked successfully.',
        ]);
    }
}
