<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Educational extends Model
{
    use HasFactory;
    protected $fillable = [ 
        'educ_elem',
        'educ_elem_year',
        'educ_hschool',
        'educ_hschool_year',
        'educ_voc',
        'educ_voc_year'

    ];
}
