<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Batch;
use App\Models\Checkpoint;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;

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
        $user = $request->user();

        $logs = Checkpoint::with('batch')
            ->when(
                $user->role !== 'admin',
                function ($query) use ($user) {
                    $query->whereHas('batch', function ($batchQuery) use ($user) {
                        if ($user->role === 'processor') {
                            $batchQuery->where('processor_id', $user->id);
                            return;
                        }

                        if ($user->role === 'logistics') {
                            $batchQuery
                                ->where('driver_id', $user->id)
                                ->orWhere('current_holder_id', $user->id);
                            return;
                        }

                        if ($user->role === 'retailer') {
                            $batchQuery->where('current_holder_id', $user->id);
                            return;
                        }

                        $batchQuery->whereRaw('1 = 0');
                    });
                }
            )
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

    /** Download a manifest PDF for the authenticated user's relevant batches. */
    public function downloadManifest(Request $request)
    {
        $user = $request->user();

        $batches = Batch::query()
            ->with(['processor:id,name', 'currentHolder:id,name'])
            ->when(
                $user->role !== 'admin',
                fn ($query) => $query->where(function ($innerQuery) use ($user) {
                    $innerQuery
                        ->where('processor_id', $user->id)
                        ->orWhere('current_holder_id', $user->id)
                        ->orWhere('driver_id', $user->id);
                })
            )
            ->orderByDesc('created_at')
            ->get();

        $pdf = Pdf::loadView('reports.manifest', [
            'batches' => $batches,
            'generatedAt' => now(),
            'generatedBy' => $user->name,
        ]);

        return $pdf->download('halal-manifest-report.pdf');
    }
}
