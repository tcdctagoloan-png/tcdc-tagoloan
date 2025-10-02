<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\personalController;
use App\Http\Controllers\educationalController;
use App\Http\Controllers\ContactController;

// Route for Personal Information Form
Route::get('personal', [personalController::class, 'personal']);
Route::post('personalsubmit', [personalController::class, 'personalsubmit']);

// Route for Educational Background Form
Route::get('educational' , [educationalController::class,'educational']);
Route::post('educationalsubmit', [educationalController::class,'educationalsubmit']);


// Route for Contact Information Form
Route::get('contact', [contactController::class, 'contact']);
Route::post('contactsubmit', [contactController::class, 'contactsubmit']);


?>

