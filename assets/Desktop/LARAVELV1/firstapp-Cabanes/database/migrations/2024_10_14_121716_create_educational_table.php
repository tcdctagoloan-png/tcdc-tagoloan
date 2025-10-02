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
        Schema::create('educational', function (Blueprint $table) {
            $table->id();
            $table->string('educ_elem');
            $table->date('educ_elemyear');
            $table->string('educ_hschool');
            $table->date('educ_hschoolyear');
            $table->string('educ_voc')->nullable();
            $table->date('educ_vocyear')->nullable();
    
            $table->timestamps();
        });
    }
    

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('educational');
    }
};
