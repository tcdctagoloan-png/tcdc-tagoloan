<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class ExampleController extends Controller
{
public function homepage() {
    $F_name= "Jane";
    return view ('Homepage',['name'=>$F_name]);
}
}

