<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Creates the primary users table with auth, role, and approval fields.
return new class extends Migration {
    /** Apply the migration. */
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            // --- Standard Auth Fields ---
            $table->id();
            $table->string('name'); // Company Name
            $table->string('email')->unique();
            $table->timestamp('email_verified_at')->nullable();
            $table->string('password');
            $table->rememberToken();

            // --- Custom Profile Fields ---
            $table->string('phone_number')->nullable();
            $table->string('profile_image')->nullable(); // [NEW] Stores 'avatars/filename.jpg'

            // --- Role & Verification ---
            $table->enum('role', ['admin', 'processor', 'logistics', 'retailer', 'consumer'])->default('consumer');
            $table->string('registration_no')->nullable(); // SSM Company No.
            $table->string('license_document_path')->nullable(); // PDF Verification

            $table->boolean('is_approved')->default(false);
            $table->timestamp('approved_at')->nullable();

            $table->timestamps();
        });
    }

    /** Roll back the migration. */
    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
