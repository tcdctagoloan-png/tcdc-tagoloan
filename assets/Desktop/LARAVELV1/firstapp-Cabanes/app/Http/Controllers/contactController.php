<?php

namespace App\Http\Controllers;

use App\Models\contact; // Ensure the model name is capitalized
use Illuminate\Http\Request;

class contactController extends Controller
{
    public function contact()
    {
        return view('contact'); // Show the contact information form
    }

    public function contactsubmit(Request $request)
    {
        $incoming_fields = $request->validate([
            'con_moth_name' => 'required',
            'con_moth_num' => 'required',
            'con_fath_name' => 'required',
            'con_fath_num' => 'required'

        ]);
        contact::create($incoming_fields);
        return 'Done!';
         }
}
