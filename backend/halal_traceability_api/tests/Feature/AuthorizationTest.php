<?php

namespace Tests\Feature;

use App\Models\Batch;
use App\Models\Checkpoint;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AuthorizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_non_admin_cannot_access_admin_stats(): void
    {
        $processor = User::factory()->create([
            'role' => 'processor',
            'phone_number' => '+60111111111',
            'is_approved' => true,
        ]);

        Sanctum::actingAs($processor);

        $this->getJson('/api/admin/stats')->assertForbidden();
    }

    public function test_admin_can_view_batch_detail(): void
    {
        $admin = User::factory()->create([
            'role' => 'admin',
            'phone_number' => '+60110000001',
            'is_approved' => true,
        ]);

        $processor = User::factory()->create([
            'role' => 'processor',
            'phone_number' => '+60111111111',
            'is_approved' => true,
        ]);

        $batch = Batch::create([
            'batch_id' => 'B-2026-ADMIN-001',
            'processor_id' => $processor->id,
            'current_holder_id' => $processor->id,
            'product_type' => 'Whole Chicken',
            'weight' => '120kg',
            'slaughter_date' => '2026-03-30',
            'origin_farm' => 'Farm QA',
            'processing_factory' => 'Plant QA',
            'current_location' => 'Shah Alam',
            'status' => 'Processing',
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/batches/' . $batch->id)
            ->assertOk()
            ->assertJsonPath('batch.batch_id', 'B-2026-ADMIN-001');
    }

    public function test_partner_registration_requires_admin_approval_before_login(): void
    {
        Storage::fake('public');

        $registration = $this->post('/api/register', [
            'name' => 'Pending Processor',
            'email' => 'pending.processor@example.com',
            'password' => 'StrongPass1',
            'role' => 'processor',
            'phone_number' => '+60119999999',
            'company_reg_no' => 'SSM-PENDING-001',
            'halal_cert_no' => 'HALAL-PENDING-001',
            'halal_expiry_date' => '2026-12-31',
            'factory_address' => 'Lot 10, Pending Factory, Shah Alam',
            'document' => UploadedFile::fake()->create('pending-certificate.pdf', 128, 'application/pdf'),
        ], ['Accept' => 'application/json']);

        $registration
            ->assertCreated()
            ->assertJsonPath('requires_approval', true)
            ->assertJsonPath('email_verification_required', true)
            ->assertJsonMissingPath('token');

        $this->postJson('/api/login', [
            'email' => 'pending.processor@example.com',
            'password' => 'StrongPass1',
        ])->assertForbidden()
            ->assertJsonPath('message', 'Please verify your email before signing in.');

        $verificationCode = $registration->json('verification_code_debug');

        $this->postJson('/api/verify-email-code', [
            'email' => 'pending.processor@example.com',
            'code' => $verificationCode,
        ])->assertOk()
            ->assertJsonPath('requires_approval', true);

        $this->postJson('/api/login', [
            'email' => 'pending.processor@example.com',
            'password' => 'StrongPass1',
        ])->assertForbidden()
            ->assertJsonPath('message', 'Your account is pending approval by admin.');
    }

    public function test_processor_registration_stores_verification_document(): void
    {
        Storage::fake('public');

        $response = $this->post('/api/register', [
            'name' => 'Document Processor',
            'email' => 'doc.processor@example.com',
            'password' => 'StrongPass1',
            'role' => 'processor',
            'phone_number' => '+60117776666',
            'company_reg_no' => 'SSM-DOC-001',
            'halal_cert_no' => 'HALAL-DOC-001',
            'halal_expiry_date' => '2026-12-31',
            'factory_address' => 'Lot 11, Shah Alam',
            'document' => UploadedFile::fake()->create('certificate.pdf', 128, 'application/pdf'),
        ], ['Accept' => 'application/json']);

        $response
            ->assertCreated()
            ->assertJsonPath('requires_approval', true);

        $user = User::where('email', 'doc.processor@example.com')->firstOrFail()->load('processorProfile');

        $this->assertNotNull($user->processorProfile);
        $this->assertNotNull($user->processorProfile->cert_document_path);
        Storage::disk('public')->assertExists($user->processorProfile->cert_document_path);
    }

    public function test_admin_pending_users_list_excludes_rejected_accounts(): void
    {
        $admin = User::factory()->create([
            'role' => 'admin',
            'phone_number' => '+60118880001',
            'is_approved' => true,
            'registration_status' => 'approved',
        ]);

        User::factory()->create([
            'role' => 'processor',
            'phone_number' => '+60118880002',
            'is_approved' => false,
            'registration_status' => 'pending',
        ]);

        User::factory()->create([
            'role' => 'processor',
            'phone_number' => '+60118880003',
            'is_approved' => false,
            'registration_status' => 'rejected',
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/users?status=pending')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.registration_status', 'pending');

        $this->getJson('/api/admin/stats')
            ->assertOk()
            ->assertJsonPath('pending_users', 1);
    }

    public function test_processor_can_create_batch_with_batch_level_certificate_document(): void
    {
        Storage::fake('public');

        $processor = User::factory()->create([
            'role' => 'processor',
            'phone_number' => '+60118880004',
            'is_approved' => true,
            'email_verified_at' => now(),
            'registration_status' => 'approved',
        ]);

        $processor->processorProfile()->create([
            'company_reg_no' => 'SSM-BATCH-001',
            'halal_cert_no' => 'PROFILE-CERT-001',
            'halal_expiry_date' => now()->addMonth()->toDateString(),
            'factory_address' => 'Lot 12, Shah Alam',
            'cert_document_path' => null,
        ]);

        Sanctum::actingAs($processor);

        $response = $this->post('/api/batches', [
            'batch_id' => 'B-2026-CERT-001',
            'product_type' => 'Chicken Wings',
            'weight' => '80kg',
            'slaughter_date' => now()->toDateString(),
            'processing_date' => now()->toDateString(),
            'origin_farm' => 'Farm QA',
            'processing_factory' => 'Plant QA',
            'current_location' => 'Shah Alam',
            'certificate_authority' => 'JAKIM',
            'certificate_no' => 'BATCH-CERT-001',
            'certificate_valid_until' => now()->addMonth()->toDateString(),
            'certificate_document' => UploadedFile::fake()->create('batch-certificate.pdf', 128, 'application/pdf'),
            'generate_qr' => true,
        ], ['Accept' => 'application/json']);

        $response
            ->assertCreated()
            ->assertJsonPath('data.certificate_no', 'BATCH-CERT-001')
            ->assertJsonPath('data.status', 'QR Generated');

        $documentPath = $response->json('data.certificate_document_path');
        $this->assertNotNull($documentPath);
        Storage::disk('public')->assertExists($documentPath);
    }

    public function test_non_logistics_cannot_submit_checkpoint(): void
    {
        $processor = User::factory()->create([
            'role' => 'processor',
            'phone_number' => '+60111111111',
            'is_approved' => true,
        ]);

        $batch = Batch::create([
            'batch_id' => 'B-2026-LOCK-001',
            'processor_id' => $processor->id,
            'current_holder_id' => $processor->id,
            'product_type' => 'Whole Chicken',
            'weight' => '120kg',
            'slaughter_date' => '2026-03-30',
            'origin_farm' => 'Farm QA',
            'processing_factory' => 'Plant QA',
            'current_location' => 'Shah Alam',
            'status' => 'Processing',
        ]);

        Sanctum::actingAs($processor);

        $this->postJson('/api/logistics/checkpoint', [
            'batch_id' => $batch->batch_id,
            'temperature' => '-18.5',
            'location' => '3.123456,101.654321',
            'latitude' => 3.123456,
            'longitude' => 101.654321,
            'signature' => 'base64-demo',
        ])->assertForbidden();
    }

    public function test_rejected_user_cannot_log_in(): void
    {
        $user = User::factory()->create([
            'email' => 'rejected.user@example.com',
            'password' => bcrypt('StrongPass1'),
            'role' => 'processor',
            'phone_number' => '+60115556666',
            'email_verified_at' => now(),
            'is_approved' => false,
            'registration_status' => 'rejected',
        ]);

        $this->postJson('/api/login', [
            'email' => $user->email,
            'password' => 'StrongPass1',
        ])->assertForbidden()
            ->assertJsonPath('message', 'Your registration was rejected. Please contact admin.');
    }

    public function test_admin_can_log_in_without_email_verification(): void
    {
        $admin = User::factory()->create([
            'email' => 'admin.unverified@example.com',
            'password' => bcrypt('StrongPass1'),
            'role' => 'admin',
            'phone_number' => '+60116667777',
            'email_verified_at' => null,
            'is_approved' => true,
            'registration_status' => 'pending',
        ]);

        $this->postJson('/api/login', [
            'email' => $admin->email,
            'password' => 'StrongPass1',
        ])->assertOk()
            ->assertJsonPath('user.role', 'admin');

        $admin->refresh();
        $this->assertNotNull($admin->email_verified_at);
        $this->assertSame('approved', $admin->registration_status);
    }

    public function test_demo_account_can_log_in_without_email_verification_or_approval(): void
    {
        $processor = User::factory()->create([
            'email' => 'ali@processor.com',
            'password' => bcrypt('StrongPass1'),
            'role' => 'processor',
            'phone_number' => '+60116667778',
            'email_verified_at' => null,
            'is_approved' => false,
            'registration_status' => 'pending',
        ]);

        $this->postJson('/api/login', [
            'email' => $processor->email,
            'password' => 'StrongPass1',
        ])->assertOk()
            ->assertJsonPath('user.role', 'processor');

        $processor->refresh();
        $this->assertNotNull($processor->email_verified_at);
        $this->assertTrue($processor->is_approved);
        $this->assertSame('approved', $processor->registration_status);
    }

    public function test_admin_can_revoke_batch_certificate_without_partial_failure(): void
    {
        $admin = User::factory()->create([
            'role' => 'admin',
            'phone_number' => '+60116667779',
            'is_approved' => true,
            'email_verified_at' => now(),
            'registration_status' => 'approved',
        ]);

        $processor = User::factory()->create([
            'role' => 'processor',
            'phone_number' => '+60116667780',
            'is_approved' => true,
            'email_verified_at' => now(),
            'registration_status' => 'approved',
        ]);

        $batch = Batch::create([
            'batch_id' => 'B-2026-REVOKE-001',
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
            'certificate_no' => 'CERT-REVOKE-001',
            'certificate_valid_until' => now()->addMonth()->toDateString(),
            'certificate_document_path' => 'batch-certificates/cert-revoke.pdf',
            'qr_code_hash' => 'signed-hash',
            'qr_code_payload' => 'BATCH:B-2026-REVOKE-001|SIG:signed-hash',
            'qr_generated_at' => now(),
            'status' => 'QR Generated',
            'halal_status' => 'compliant',
        ]);

        Sanctum::actingAs($admin);

        $this->postJson("/api/admin/batches/{$batch->id}/revoke-certificate")
            ->assertOk()
            ->assertJsonPath('message', 'Batch certificate revoked successfully.');

        $batch->refresh();
        $this->assertNotNull($batch->qr_revoked_at);
        $this->assertSame('Invalid - Certificate Revoked', $batch->status);
        $this->assertSame('breached', $batch->halal_status);

        $this->assertDatabaseHas('checkpoints', [
            'batch_id' => $batch->id,
            'user_id' => $admin->id,
            'action_type' => 'transit_update',
            'notes' => 'Certificate revoked by administrator.',
        ]);
    }

    public function test_unassigned_retailer_cannot_accept_another_retailers_batch(): void
    {
        $processor = User::factory()->create([
            'role' => 'processor',
            'phone_number' => '+60111111111',
            'is_approved' => true,
        ]);

        $retailer = User::factory()->create([
            'role' => 'retailer',
            'phone_number' => '+60112222222',
            'is_approved' => true,
        ]);
        $retailer->retailerProfile()->create([
            'store_name' => 'Review Store',
            'business_reg_no' => 'SSM-REV-001',
            'outlet_address' => 'Review Outlet KL',
        ]);

        $batch = Batch::create([
            'batch_id' => 'B-2026-LOCK-002',
            'processor_id' => $processor->id,
            'current_holder_id' => $processor->id,
            'product_type' => 'Chicken Wings',
            'weight' => '80kg',
            'slaughter_date' => '2026-03-30',
            'origin_farm' => 'Farm QA',
            'processing_factory' => 'Plant QA',
            'current_location' => 'Shah Alam',
            'destination_address' => 'Different Outlet PJ',
            'status' => 'In Transit',
        ]);

        Sanctum::actingAs($retailer);

        $this->postJson('/api/retailer/accept', [
            'batch_id' => $batch->batch_id,
            'arrival_temperature' => 2.5,
            'quality_checks' => [
                'packaging_intact' => true,
                'temperature_check' => true,
                'halal_cert_present' => true,
                'quantity_match' => true,
                'expiry_valid' => true,
            ],
        ])->assertForbidden();
    }
}
