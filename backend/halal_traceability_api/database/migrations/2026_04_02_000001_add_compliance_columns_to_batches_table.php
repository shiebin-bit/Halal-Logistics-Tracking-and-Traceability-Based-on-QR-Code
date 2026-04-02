<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('batches', function (Blueprint $table) {
            if (!Schema::hasColumn('batches', 'processing_date')) {
                $table->date('processing_date')->nullable()->after('slaughter_date');
            }

            if (!Schema::hasColumn('batches', 'certificate_authority')) {
                $table->string('certificate_authority')->nullable()->after('current_location');
            }

            if (!Schema::hasColumn('batches', 'certificate_no')) {
                $table->string('certificate_no')->nullable()->after('certificate_authority');
            }

            if (!Schema::hasColumn('batches', 'certificate_valid_until')) {
                $table->date('certificate_valid_until')->nullable()->after('certificate_no');
            }

            if (!Schema::hasColumn('batches', 'certificate_document_path')) {
                $table->string('certificate_document_path')->nullable()->after('certificate_valid_until');
            }

            if (!Schema::hasColumn('batches', 'qr_code_payload')) {
                $table->text('qr_code_payload')->nullable()->after('qr_code_hash');
            }

            if (!Schema::hasColumn('batches', 'qr_generated_at')) {
                $table->timestamp('qr_generated_at')->nullable()->after('qr_code_payload');
            }

            if (!Schema::hasColumn('batches', 'qr_revoked_at')) {
                $table->timestamp('qr_revoked_at')->nullable()->after('qr_generated_at');
            }
        });
    }

    public function down(): void
    {
        Schema::table('batches', function (Blueprint $table) {
            foreach ([
                'qr_revoked_at',
                'qr_generated_at',
                'qr_code_payload',
                'certificate_document_path',
                'certificate_valid_until',
                'certificate_no',
                'certificate_authority',
                'processing_date',
            ] as $column) {
                if (Schema::hasColumn('batches', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
