<?php

namespace App\Models; // Adjust namespace based on your app structure

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Personal extends Model
{
    use HasFactory;
    protected $table = 'personal';
    protected $fillable = [
        'per_fname',
        'per_lname',
        'per_address',
        'per_birthday',
    ];
}
