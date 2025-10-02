<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class ExampleController extends Controller
{
public function homepage() {
    $F_name= "Aiziel";
    return view ('Homepage',['name'=>$F_name]);
}
}

