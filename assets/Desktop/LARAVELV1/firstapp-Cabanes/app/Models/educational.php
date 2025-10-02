<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Educational extends Model
{
    use HasFactory;
    protected $table = 'educational';
    protected $fillable = [
        'educ_elem',
        'educ_elemyear',
        'educ_hschool',
        'educ_hschoolyear',
        
        
    ];

   
    
}
