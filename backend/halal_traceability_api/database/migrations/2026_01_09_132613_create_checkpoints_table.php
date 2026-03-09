<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Creates immutable checkpoint events for audit trail and chain-of-custody.
return new class extends Migration {
    /** Apply the migration. */
    public function up()
    {
        Schema::create('checkpoints', function (Blueprint $table) {
            $table->id();

            // Links
            // Note: Make sure 'batches' and 'users' tables exist before running this!
            $table->foreignId('batch_id')->constrained('batches')->onDelete('cascade');
            $table->foreignId('user_id')->constrained('users'); // The Driver

            // Location Data
            $table->string('location_name')->nullable();
            $table->decimal('latitude', 10, 8)->nullable();
            $table->decimal('longitude', 11, 8)->nullable();

            // Condition Monitoring
            $table->decimal('temperature', 5, 2);

            // We use string here to be flexible (e.g. 'Delivered', 'Check-in')
            $table->string('action_type')->default('transit_update');

            $table->text('notes')->nullable();

            // --- ADD THIS LINE FOR SIGNATURES ---
            $table->string('signature_path')->nullable();
            // ------------------------------------

            $table->timestamps();
        });
    }

    /** Roll back the migration. */
    public function down(): void
    {
        Schema::dropIfExists('checkpoints');
    }
};
