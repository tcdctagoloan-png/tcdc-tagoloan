<?php

namespace App\Http\Controllers; 

use App\Models\Personal; 
use Illuminate\Http\Request;

class PersonalController extends Controller
{
    public function personal()
    {
        return view ('personal'); 
    }

    public function personalsubmit(Request $request)
    {
        $incoming_fields = $request->validate([
            'per_fname' => 'required',
            'per_lname' => 'required',
            #'per_address' => 'nullable',
            #'per_birthday' => 'nullable'

        ]);
    personal::create($incoming_fields);
    return  view ('educational');
    }
}
