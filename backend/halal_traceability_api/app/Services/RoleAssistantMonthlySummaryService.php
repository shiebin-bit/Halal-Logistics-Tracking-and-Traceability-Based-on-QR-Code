<?php

namespace App\Services;

use App\Models\Batch;
use App\Models\Checkpoint;
use App\Models\Incident;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

class RoleAssistantMonthlySummaryService
{
    public function buildFor(User $user): array
    {
        $periodStart = now()->startOfMonth();
        $periodEnd = now()->endOfMonth();

        return [
            'period' => [
                'label' => $periodStart->format('F Y'),
                'from' => $periodStart->toDateString(),
                'to' => $periodEnd->toDateString(),
            ],
            'role_summary' => match ($user->role) {
                'processor' => $this->processorSummary($user, $periodStart, $periodEnd),
                'logistics' => $this->logisticsSummary($user, $periodStart, $periodEnd),
                'retailer' => $this->retailerSummary($user, $periodStart, $periodEnd),
                default => [
                    'message' => 'Monthly operational summary is not available for this role.',
                ],
            },
        ];
    }

    private function processorSummary(User $user, Carbon $periodStart, Carbon $periodEnd): array
    {
        $query = Batch::query()
            ->where('processor_id', $user->id)
            ->whereBetween('created_at', [$periodStart, $periodEnd]);

        $recentBatches = (clone $query)
            ->latest('created_at')
            ->limit(3)
            ->get();

        return [
            'created_batches_this_month' => (clone $query)->count(),
            'status_breakdown' => $this->statusBreakdown($query),
            'recent_batches' => $this->mapBatches($recentBatches),
        ];
    }

    private function logisticsSummary(User $user, Carbon $periodStart, Carbon $periodEnd): array
    {
        $routeQuery = Batch::query()
            ->where(function (Builder $query) use ($user) {
                $query->where('driver_id', $user->id)
                    ->orWhere('current_holder_id', $user->id);
            })
            ->whereBetween('updated_at', [$periodStart, $periodEnd]);

        $recentRoutes = (clone $routeQuery)
            ->latest('updated_at')
            ->limit(3)
            ->get();

        $checkpointCount = Checkpoint::query()
            ->where('user_id', $user->id)
            ->whereBetween('created_at', [$periodStart, $periodEnd])
            ->count();

        $incidentCount = Incident::query()
            ->where('user_id', $user->id)
            ->whereBetween('created_at', [$periodStart, $periodEnd])
            ->count();

        return [
            'routes_touched_this_month' => (clone $routeQuery)->count(),
            'status_breakdown' => $this->statusBreakdown($routeQuery),
            'checkpoints_submitted_this_month' => $checkpointCount,
            'incidents_reported_this_month' => $incidentCount,
            'recent_routes' => $this->mapBatches($recentRoutes),
        ];
    }

    private function retailerSummary(User $user, Carbon $periodStart, Carbon $periodEnd): array
    {
        $visibleBatchQuery = $this->retailerVisibleBatchQuery($user)
            ->whereBetween('updated_at', [$periodStart, $periodEnd]);

        $recentShipments = (clone $visibleBatchQuery)
            ->latest('updated_at')
            ->limit(3)
            ->get();

        $receivedCount = Batch::query()
            ->where('current_holder_id', $user->id)
            ->where('status', 'Delivered')
            ->whereBetween('updated_at', [$periodStart, $periodEnd])
            ->count();

        $rejectionCount = Incident::query()
            ->where('user_id', $user->id)
            ->where('issue_type', 'Retail Rejection')
            ->whereBetween('created_at', [$periodStart, $periodEnd])
            ->count();

        return [
            'visible_shipments_this_month' => (clone $visibleBatchQuery)->count(),
            'status_breakdown' => $this->statusBreakdown($visibleBatchQuery),
            'received_inventory_this_month' => $receivedCount,
            'rejections_logged_this_month' => $rejectionCount,
            'recent_shipments' => $this->mapBatches($recentShipments),
        ];
    }

    private function retailerVisibleBatchQuery(User $user): Builder
    {
        $searchTerms = $this->buildRetailerSearchTerms($user);

        return Batch::query()->where(function (Builder $query) use ($user, $searchTerms) {
            $query->where('current_holder_id', $user->id);

            if ($searchTerms === []) {
                return;
            }

            $query->orWhere(function (Builder $destinationQuery) use ($searchTerms) {
                foreach ($searchTerms as $term) {
                    $destinationQuery->orWhere('destination_address', 'LIKE', "%{$term}%");
                }
            });
        });
    }

    private function buildRetailerSearchTerms(User $user): array
    {
        $retailerProfile = $user->retailerProfile;
        if (!$retailerProfile) {
            return [];
        }

        $excludedWords = [
            'outlet', 'store', 'jalan', 'road', 'street', 'lorong',
            'taman', 'bandar', 'blok', 'block', 'mall', 'plaza',
            'floor', 'level', 'suite', 'unit', 'lot',
        ];

        $searchTerms = [];
        $storeName = $retailerProfile->store_name ?? '';
        $outletAddress = $retailerProfile->outlet_address ?? '';

        if ($storeName) {
            $words = preg_split('/\s+/', trim($storeName));
            $searchTerms[] = count($words) >= 2 ? implode(' ', array_slice($words, 0, 2)) : $storeName;
        }

        if ($outletAddress) {
            $searchTerms[] = $outletAddress;
            $addrWords = preg_split('/\s+/', str_replace([',', '.'], '', $outletAddress));
            foreach ($addrWords as $word) {
                $word = trim($word);
                if (strlen($word) >= 5 && !in_array(strtolower($word), $excludedWords, true)) {
                    $searchTerms[] = $word;
                }
            }
        }

        return array_values(array_unique(array_filter($searchTerms)));
    }

    private function statusBreakdown(Builder $query): array
    {
        return (clone $query)
            ->selectRaw('status, COUNT(*) as aggregate')
            ->groupBy('status')
            ->pluck('aggregate', 'status')
            ->map(fn ($count) => (int) $count)
            ->all();
    }

    private function mapBatches(Collection $batches): array
    {
        return $batches->map(function (Batch $batch): array {
            return [
                'batch_id' => $batch->batch_id,
                'product_type' => $batch->product_type,
                'status' => $batch->status,
                'current_location' => $batch->current_location,
                'destination_address' => $batch->destination_address,
                'updated_at' => optional($batch->updated_at)->toIso8601String(),
                'created_at' => optional($batch->created_at)->toIso8601String(),
            ];
        })->values()->all();
    }
}
