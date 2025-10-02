<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class StudentRegistration extends Model
{
    use HasFactory;
    protected $fillable = [ 
        'stud_id',
        'stud_fname',
        'stud_address',
        'stud_birthday',
        'stud_ylevel',
        'stud_block'
    ];
}
