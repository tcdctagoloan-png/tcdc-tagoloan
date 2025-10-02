<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class RegisterClass extends Model
{
    use HasFactory;
    protected $fillable = [ 
        'class_id',
        'class_name',
        'class_schedule',
        'stud_id'
    ];
}
