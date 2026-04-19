<?php

namespace Tests\Feature;

use App\Models\Batch;
use App\Models\Checkpoint;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExampleTest extends TestCase
{
    use RefreshDatabase;

    /** The public consumer batch listing returns a paginated response. */
    public function test_public_batches_endpoint_returns_paginated_data(): void
    {
        $processor = User::factory()->create([
            'role' => 'processor',
            'phone_number' => '+60111111111',
            'is_approved' => true,
        ]);

        Batch::create([
            'batch_id' => 'B-2026-TEST-001',
            'processor_id' => $processor->id,
            'current_holder_id' => $processor->id,
            'product_type' => 'Whole Chicken',
            'weight' => '120kg',
            'slaughter_date' => '2026-03-30',
            'processing_date' => '2026-03-30',
            'origin_farm' => 'Farm QA',
            'processing_factory' => 'Plant QA',
            'current_location' => 'Shah Alam',
            'certificate_authority' => 'JAKIM',
            'certificate_no' => 'CERT-TEST-001',
            'certificate_valid_until' => now()->addMonth()->toDateString(),
            'certificate_document_path' => 'batch-certificates/cert-test.pdf',
            'qr_code_hash' => 'signed-hash',
            'qr_code_payload' => 'BATCH:B-2026-TEST-001|SIG:signed-hash',
            'qr_generated_at' => now(),
            'status' => 'QR Generated',
        ]);

        $response = $this->getJson('/api/public/batches');

        $response
            ->assertOk()
            ->assertJsonPath('data.0.batch_id', 'B-2026-TEST-001');
    }

    public function test_public_batch_detail_hides_internal_actor_fields(): void
    {
        $processor = User::factory()->create([
            'role' => 'processor',
            'phone_number' => '+60112223333',
            'is_approved' => true,
            'email_verified_at' => now(),
        ]);

        $batch = Batch::create([
            'batch_id' => 'B-2026-PUBLIC-001',
            'processor_id' => $processor->id,
            'current_holder_id' => $processor->id,
            'product_type' => 'Whole Chicken',
            'weight' => '120kg',
            'slaughter_date' => '2026-03-30',
            'processing_date' => '2026-03-30',
            'origin_farm' => 'Farm QA',
            'processing_factory' => 'Plant QA',
            'current_location' => 'Shah Alam',
            'certificate_authority' => 'JAKIM',
            'certificate_no' => 'CERT-001',
            'certificate_valid_until' => now()->addMonth()->toDateString(),
            'certificate_document_path' => 'batch-certificates/cert-001.pdf',
            'qr_code_hash' => 'signed-hash',
            'qr_code_payload' => 'BATCH:B-2026-PUBLIC-001|SIG:signed-hash',
            'qr_generated_at' => now(),
            'status' => 'QR Generated',
        ]);

        Checkpoint::create([
            'batch_id' => $batch->id,
            'user_id' => $processor->id,
            'location_name' => 'Shah Alam',
            'latitude' => 3.0738,
            'longitude' => 101.5183,
            'temperature' => 2,
            'action_type' => 'transit_update',
            'notes' => 'Internal note that must not leak',
        ]);

        $response = $this->getJson('/api/public/batches/B-2026-PUBLIC-001');

        $response
            ->assertOk()
            ->assertJsonMissingPath('batch.checkpoints.0.actor_name')
            ->assertJsonMissingPath('batch.checkpoints.0.actor_role')
            ->assertJsonMissingPath('batch.checkpoints.0.notes')
            ->assertJsonPath('batch.checkpoints.0.latitude', 3.0738)
            ->assertJsonPath('batch.checkpoints.0.longitude', 101.5183)
            ->assertJsonPath('batch.checkpoints.0.summary', 'Transit update');
    }

    public function test_public_batch_detail_supports_legacy_hash_only_qr_data(): void
    {
        $processor = User::factory()->create([
            'role' => 'processor',
            'phone_number' => '+60112225555',
            'is_approved' => true,
            'email_verified_at' => now(),
        ]);

        Batch::create([
            'batch_id' => 'B-2026-LEGACY-QR-001',
            'processor_id' => $processor->id,
            'current_holder_id' => $processor->id,
            'product_type' => 'Whole Chicken',
            'weight' => '120kg',
            'slaughter_date' => '2026-03-30',
            'processing_date' => '2026-03-30',
            'origin_farm' => 'Farm QA',
            'processing_factory' => 'Plant QA',
            'current_location' => 'Shah Alam',
            'certificate_authority' => 'JAKIM',
            'certificate_no' => 'CERT-LEGACY-001',
            'certificate_valid_until' => now()->addMonth()->toDateString(),
            'certificate_document_path' => 'batch-certificates/cert-legacy.pdf',
            'qr_code_hash' => 'legacy-signed-hash',
            'status' => 'In Transit',
        ]);

        $this->getJson('/api/public/batches')
            ->assertOk()
            ->assertJsonPath('data.0.batch_id', 'B-2026-LEGACY-QR-001');

        $this->getJson('/api/public/batches/B-2026-LEGACY-QR-001')
            ->assertOk()
            ->assertJsonPath(
                'batch.qr_code_payload',
                'BATCH:B-2026-LEGACY-QR-001|SIG:legacy-signed-hash'
            );
    }

    public function test_revoked_batch_is_not_available_to_public(): void
    {
        $processor = User::factory()->create([
            'role' => 'processor',
            'phone_number' => '+60112224444',
            'is_approved' => true,
            'email_verified_at' => now(),
        ]);

        Batch::create([
            'batch_id' => 'B-2026-REVOKED-001',
            'processor_id' => $processor->id,
            'current_holder_id' => $processor->id,
            'product_type' => 'Whole Chicken',
            'weight' => '120kg',
            'slaughter_date' => '2026-03-30',
            'processing_date' => '2026-03-30',
            'origin_farm' => 'Farm QA',
            'processing_factory' => 'Plant QA',
            'current_location' => 'Shah Alam',
            'certificate_authority' => 'JAKIM',
            'certificate_no' => 'CERT-REVOKED-001',
            'certificate_valid_until' => now()->addMonth()->toDateString(),
            'certificate_document_path' => 'batch-certificates/cert-revoked.pdf',
            'qr_code_hash' => 'signed-hash',
            'qr_code_payload' => 'BATCH:B-2026-REVOKED-001|SIG:signed-hash',
            'qr_generated_at' => now(),
            'qr_revoked_at' => now(),
            'status' => 'Invalid - Certificate Revoked',
            'halal_status' => 'breached',
        ]);

        $this->getJson('/api/public/batches/B-2026-REVOKED-001')
            ->assertStatus(422)
            ->assertJsonPath('code', 'BATCH_NOT_PUBLIC');
    }
}
