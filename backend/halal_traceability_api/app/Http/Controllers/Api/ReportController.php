<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Checkpoint;
use Illuminate\Support\Facades\Auth;

/**
 * Handles report generation: audit logs and manifest downloads.
 */
class ReportController extends Controller
{
    /**
     * Get the 50 most recent audit log entries with batch info.
     */
    public function getAuditLogs(Request $request)
    {
        $logs = Checkpoint::with('batch')
            ->orderBy('created_at', 'desc')
            ->limit(50)
            ->get();

        $formattedLogs = $logs->map(function ($log) {
            return [
                'batch_id' => $log->batch ? $log->batch->batch_id : 'Unknown',
                'action' => ucfirst($log->action_type) . ": " . ($log->notes ?? ''),
                'timestamp' => $log->created_at->format('d M Y, h:i A'),
                'location' => $log->location_name,
            ];
        });

        return response()->json(['data' => $formattedLogs]);
    }

    /**
     * Download a manifest PDF (placeholder — requires dompdf library for full implementation).
     */
    public function downloadManifest()
    {
        return response()->json(['message' => 'PDF Service Placeholder'], 200);
    }
}