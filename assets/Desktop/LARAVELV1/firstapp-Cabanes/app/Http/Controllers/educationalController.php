<?php

namespace App\Http\Controllers;

use App\Models\Educational; 
use Illuminate\Http\Request;

class educationalController extends Controller
{
    public function educational()
    {
        return view('educational');
    }

    public function educationalsubmit(Request $request)
    {
        $incoming_fields = $request->validate([
            'educ_elem' => 'required',
            'educ_elemyear' => 'required',
            'educ_hschool' => 'required',
            'educ_hschoolyear' => 'required'
        ]);

        educational::create($incoming_fields);
        return view ('contact');
    }
}
