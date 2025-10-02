<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Contact extends Model
{
    use HasFactory;
    protected $fillable = [ 
        'moth_name',
        'moth_num',
        'fath_name',
        'fath_num',
        'guard_name',
        'guard_num'

    ];
}
