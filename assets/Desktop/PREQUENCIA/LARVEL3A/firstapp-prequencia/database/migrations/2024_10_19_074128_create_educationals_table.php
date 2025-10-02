<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('educationals', function (Blueprint $table) {
            $table->id('educ_id');
            $table->string('educ_elem');
            $table->date('educ_elem_year');
            $table->string('educ_hschool');
            $table->date('educ_hschool_year');
            $table->string('educ_voc');
            $table->date('educ_voc_year');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('educationals');
    }
};
