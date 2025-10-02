<?php

namespace App\Http\Controllers;
use App\Models\User;
use Illuminate\Http\Request;

class usercontroller extends Controller
{
    public function homepage(){
        return view('homepage');
    }

    public function submit(Request $request) {
        $incoming_fields = $request->validate([
        'username'=>'required',
        'email'=>'required',
        'password'=>'required'
        ]);

        User::create($incoming_fields);

        return "hello, Submitted";
    }
           
}
