<?php

namespace Tests\Feature;

use App\Models\Batch;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReportManifestTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_download_manifest_pdf(): void
    {
        $user = User::factory()->create([
            'role' => 'processor',
            'phone_number' => '+60123456789',
            'is_approved' => true,
        ]);

        Batch::create([
            'batch_id' => 'B-2026-001',
            'processor_id' => $user->id,
            'current_holder_id' => $user->id,
            'product_type' => 'Whole Chicken',
            'weight' => '500kg',
            'slaughter_date' => '2026-03-01',
            'origin_farm' => 'Farm A',
            'processing_factory' => 'Plant 1',
            'current_location' => 'Shah Alam',
            'status' => 'Processing',
        ]);

        Sanctum::actingAs($user);

        $response = $this->get('/api/reports/manifest');

        $response
            ->assertOk()
            ->assertHeader('content-type', 'application/pdf')
            ->assertHeader('content-disposition', 'attachment; filename=halal-manifest-report.pdf');
    }
}
