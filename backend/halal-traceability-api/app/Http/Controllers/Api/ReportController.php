<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Checkpoint;
use Illuminate\Support\Facades\Auth;

class ReportController extends Controller
{
    public function getAuditLogs(Request $request)
    {
        $user = Auth::user();

        // Get recent 50 logs, latest first
        // eager load 'batch' so we can show Batch ID string
        $logs = Checkpoint::with('batch')
            ->orderBy('created_at', 'desc')
            ->limit(50)
            ->get();

        // Format for Flutter
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

    public function downloadManifest()
    {
        // For now, return a dummy success to prevent crash
        // Real PDF generation requires 'dompdf' library
        return response()->json(['message' => 'PDF Service Placeholder'], 200);
    }
}