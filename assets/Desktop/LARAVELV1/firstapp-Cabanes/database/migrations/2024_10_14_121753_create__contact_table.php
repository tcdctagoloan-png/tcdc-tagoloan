table contact

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
        Schema::create('contact', function (Blueprint $table) {
            $table->id();
            $table->string('con_moth_name');
            $table->integer('con_moth_num');
            $table->string('con_fath_name');
            $table->integer('con_fath_num');
            $table->string('con_guardname')->nullable();
            $table->integer('con_guardnum')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('_contact');
    }
};



