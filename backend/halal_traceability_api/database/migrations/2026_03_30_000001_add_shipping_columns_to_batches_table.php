<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('batches', function (Blueprint $table) {
            if (!Schema::hasColumn('batches', 'driver_id')) {
                $table->foreignId('driver_id')->nullable()->after('halal_status')->constrained('users');
            }

            if (!Schema::hasColumn('batches', 'truck_plate')) {
                $table->string('truck_plate')->nullable()->after('driver_id');
            }

            if (!Schema::hasColumn('batches', 'destination_address')) {
                $table->string('destination_address')->nullable()->after('truck_plate');
            }

            if (!Schema::hasColumn('batches', 'estimated_arrival')) {
                $table->dateTime('estimated_arrival')->nullable()->after('destination_address');
            }
        });
    }

    public function down(): void
    {
        Schema::table('batches', function (Blueprint $table) {
            if (Schema::hasColumn('batches', 'estimated_arrival')) {
                $table->dropColumn('estimated_arrival');
            }

            if (Schema::hasColumn('batches', 'destination_address')) {
                $table->dropColumn('destination_address');
            }

            if (Schema::hasColumn('batches', 'truck_plate')) {
                $table->dropColumn('truck_plate');
            }

            if (Schema::hasColumn('batches', 'driver_id')) {
                $table->dropConstrainedForeignId('driver_id');
            }
        });
    }
};
