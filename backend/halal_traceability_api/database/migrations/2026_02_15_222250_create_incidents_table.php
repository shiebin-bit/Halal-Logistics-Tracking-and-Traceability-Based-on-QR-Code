<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up()
    {
        Schema::create('incidents', function (Blueprint $table) {
            $table->id();
            $table->string('batch_id')->index(); // Linked to the batch QR code
            $table->foreignId('user_id')->constrained()->onDelete('cascade'); // Who reported it
            $table->string('issue_type'); // Spoilage, Theft, Accident
            $table->text('description')->nullable();
            $table->string('location')->nullable();
            $table->string('status')->default('Open'); // Default status
            $table->timestamps(); // Creates created_at and updated_at
        });
    }

    public function down()
    {
        Schema::dropIfExists('incidents');
    }
};