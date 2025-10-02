<?php

use Illuminate\Support\Facades\Route;
Use App\Http\Controllers\UserController;

Route::get('/',[UserController::class,'showlogin']); //get -> viewing
Route::get('/homepage',[UserController::class,'homepage']); //get -> viewing
Route::post('/submit',[UserController::class,'submit']); //post -> getting/passing values to your database

Route::post('/login',[UserController::class,'login']); //post -> getting/passing values to your database

Route::post('/logout',[UserController::class,'logout']); //post -> getting/passing values to your database

Route::get('/welcome',[UserController::class,'welcome']); //get -> viewing
