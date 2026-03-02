<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up()
    {
        // 1. Processor Profile
        Schema::create('processor_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('company_reg_no'); // SSM
            $table->string('halal_cert_no');
            $table->date('halal_expiry_date');
            $table->text('factory_address');
            $table->string('cert_document_path')->nullable();
            $table->timestamps();
        });

        // 2. Logistics Profile (Drivers)
        Schema::create('logistics_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('vehicle_plate_no');
            $table->string('driver_license_no');
            $table->string('vehicle_type'); // Truck, Van, etc.
            $table->string('gdl_license_path')->nullable(); // GDL Document
            $table->timestamps();
        });

        // 3. Retailer Profile
        Schema::create('retailer_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('store_name');
            $table->string('business_reg_no'); // SSM
            $table->text('outlet_address');
            $table->string('store_contact_number')->nullable();
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('retailer_profiles');
        Schema::dropIfExists('logistics_profiles');
        Schema::dropIfExists('processor_profiles');
    }
};