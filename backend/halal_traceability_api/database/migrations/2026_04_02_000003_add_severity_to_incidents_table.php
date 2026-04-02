<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('incidents', function (Blueprint $table) {
            if (!Schema::hasColumn('incidents', 'severity')) {
                $table->string('severity')->default('moderate')->after('status');
            }
        });
    }

    public function down(): void
    {
        Schema::table('incidents', function (Blueprint $table) {
            if (Schema::hasColumn('incidents', 'severity')) {
                $table->dropColumn('severity');
            }
        });
    }
};
