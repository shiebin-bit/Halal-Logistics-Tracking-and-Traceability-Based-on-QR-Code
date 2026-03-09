<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Creates transfer records when custody changes between stakeholders.
return new class extends Migration {
    /** Apply the migration. */
    public function up()
    {
        Schema::create('transfers', function (Blueprint $table) {
            $table->id();

            $table->foreignId('batch_id')->constrained('batches');
            $table->foreignId('from_user_id')->constrained('users'); // Logistics
            $table->foreignId('to_user_id')->constrained('users');   // Retailer

            // Quality Checks (From Retailer Dashboard)
            $table->boolean('packaging_check_passed');
            $table->boolean('seal_check_passed');
            $table->boolean('temp_check_passed');

            // Digital Signature
            $table->string('digital_signature_hash')->nullable(); // Simulating the signature

            $table->timestamp('transferred_at');
        });
    }

    /** Roll back the migration. */
    public function down(): void
    {
        Schema::dropIfExists('transfers');
    }
};
