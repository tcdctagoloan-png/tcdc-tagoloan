<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Contact extends Model
{
    use HasFactory;
    protected $table = 'contact';
    protected $fillable = [
        'con_moth_name',
        'con_moth_num',
        'con_fath_name',
        'con_fath_num',
        'con_guardname',
        'con_guardnum',
    ];
}
