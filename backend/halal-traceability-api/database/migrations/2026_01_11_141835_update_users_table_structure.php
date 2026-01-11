<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up()
    {
        Schema::table('users', function (Blueprint $table) {
            // Remove fields that are moving to specific tables
            $table->dropColumn(['registration_no', 'license_document_path']);
            // Keep phone_number and profile_image as they are common to all
        });
    }

    public function down()
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('registration_no')->nullable();
            $table->string('license_document_path')->nullable();
        });
    }
};