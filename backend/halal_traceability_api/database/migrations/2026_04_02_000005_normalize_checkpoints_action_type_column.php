<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('checkpoints') || !Schema::hasColumn('checkpoints', 'action_type')) {
            return;
        }

        $driver = Schema::getConnection()->getDriverName();

        if (in_array($driver, ['mysql', 'mariadb'], true)) {
            DB::statement("ALTER TABLE checkpoints MODIFY action_type VARCHAR(255) NOT NULL DEFAULT 'transit_update'");
        }
    }

    public function down(): void
    {
        if (!Schema::hasTable('checkpoints') || !Schema::hasColumn('checkpoints', 'action_type')) {
            return;
        }

        $driver = Schema::getConnection()->getDriverName();

        if (in_array($driver, ['mysql', 'mariadb'], true)) {
            DB::statement("ALTER TABLE checkpoints MODIFY action_type ENUM('departure','transit_update','arrival','handover') NOT NULL DEFAULT 'transit_update'");
        }
    }
};
