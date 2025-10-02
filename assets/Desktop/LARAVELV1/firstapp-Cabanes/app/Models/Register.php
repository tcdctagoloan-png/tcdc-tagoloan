<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Register extends Model
{
    use HasFactory;
    protected $table = 'register';
    protected $fillable = [
        'per_fname',
        'per_lname',
        'per_address',
        'per_birthday',
    ];
}

