<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Validate\Rule;
use App\Http\Controllers\UserController;

Route::get('/personal', [UserController::class, 'personal']);
Route::get('/educational', [UserController::class, 'educational']);
Route::get('/contact', [UserController::class, 'contact']);
Route::get('/studentregistration', [UserController::class, 'studentregistration']);
Route::get('/registerclass', [UserController::class, 'registerclass']);
Route::get('/demo', [UserController::class, 'demo']);

Route::post('/submit-personal', [UserController::class, 'submitPersonal']);
Route::post('/submit-educational', [UserController::class, 'submitEducational']);
Route::post('/submit-contact', [UserController::class, 'submitContact']);
Route::post('/submit-studentregistration', [UserController::class, 'submitStudentRegistration']);
Route::post('/submit-registerclass', [UserController::class, 'submitRegisterClass']);
Route::post('/submit-demo', [UserController::class, 'submitDemo']);


