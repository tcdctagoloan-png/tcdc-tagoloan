<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ExampleController;
use App\Http\controllers\userController;


Route::get('/homepage',[userController::class,'homepage']);

Route::post('/submit',[userController::class,'submit']);