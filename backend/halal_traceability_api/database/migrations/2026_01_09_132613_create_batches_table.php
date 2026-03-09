<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Creates core batch records used for end-to-end halal traceability.
return new class extends Migration {
    /** Apply the migration. */
    public function up(): void
    {
        Schema::create('batches', function (Blueprint $table) {
            $table->id();
            $table->string('batch_id')->unique(); // e.g., B-2025-001

            // --- Ownership & Links ---
            $table->foreignId('processor_id')->constrained('users'); // The creator
            $table->foreignId('current_holder_id')->nullable()->constrained('users'); // Who has it now

            // --- Product Details ---
            $table->string('product_type'); // e.g., Whole Chicken
            $table->string('weight');       // e.g., "500kg" (String is safer for units, or use decimal)
            $table->date('slaughter_date');

            // --- [NEW] Origin & Location Details ---
            $table->string('origin_farm');        // e.g., "Farm A"
            $table->string('processing_factory'); // e.g., "Plant 1"
            $table->string('current_location');   // e.g., "Lot 88, Shah Alam..."

            // --- Traceability & Blockchain ---
            $table->string('qr_code_hash')->nullable(); // Matches Flutter '_blockchainHash'
            $table->string('status')->default('Processing'); // Processing, Ready, In Transit
            $table->integer('freshness_score')->default(100);
            $table->enum('halal_status', ['compliant', 'breached', 'investigation'])->default('compliant');

            $table->timestamps();
        });
    }

    /** Roll back the migration. */
    public function down(): void
    {
        Schema::dropIfExists('batches');
    }
};
