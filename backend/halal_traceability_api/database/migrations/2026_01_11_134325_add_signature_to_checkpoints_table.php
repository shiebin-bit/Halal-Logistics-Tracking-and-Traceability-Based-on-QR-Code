<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Adds digital signature storage for proof-of-handover in checkpoints.
return new class extends Migration {
    /** Apply the migration. */
    public function up()
    {
        Schema::table('checkpoints', function (Blueprint $table) {
            // Only add the column if it doesn't exist yet
            if (!Schema::hasColumn('checkpoints', 'signature_path')) {
                $table->string('signature_path')->nullable()->after('notes');
            }

            // Fix action_type to be a string (flexible) instead of strict ENUM
            // if you previously had it as enum
            // $table->string('action_type')->change(); 
        });
    }

    /** Roll back the migration. */
    public function down()
    {
        Schema::table('checkpoints', function (Blueprint $table) {
            $table->dropColumn('signature_path');
        });
    }
};
