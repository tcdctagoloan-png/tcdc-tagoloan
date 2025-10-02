<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

use App\Models\Personal;
use App\Models\Educational;
use App\Models\Contact;
use App\Models\StudentRegistration;
use App\Models\RegisterClass;
use App\Models\Demo;

class UserController extends Controller
{
    public function personal()
    {
        return view('personal');
    }
    public function educational()
    {
        return view('educational');
    }
    public function contact()
    {
        return view('contact');
    }
    public function studentregistration()
    {
        return view('studentregistration');
    }
    public function registerclass()
    {
        return view('registerclass');
    }

    public function demo()
    {
        return view('demo');
    }

    public function submitPersonal(Request $request)
    {
        $incoming_fields1 = $request->validate([
            'fname' => 'required',
            'lname' => 'required',
            'address' => 'required',
            'birthday' => 'required',
        ]);
        Personal::create($incoming_fields1);
        return view('educational');
    }

    public function submitEducational(Request $request)
    {
        $incoming_fields2 = $request->validate([
            'educ_elem' => 'required',
            'educ_elem_year' => 'required',
            'educ_hschool' => 'required',
            'educ_hschool_year' => 'required',
            'educ_voc' => 'nullable',
            'educ_voc_year' => 'nullable'
        ]);
        Educational::create($incoming_fields2);
        return view('contact');
    }
    public function submitContact(Request $request)
    {
        $incoming_fields3 = $request->validate([
            'moth_name' => 'required',
            'moth_num' => 'required',
            'fath_name' => 'required',
            'fath_num' => 'required',
            'guard_name' => 'nullable',
            'guard_num' => 'nullable'
        ]);
        Contact::create($incoming_fields3);
        return 'SUCCESS';
    }
    public function submitStudentRegistration(Request $request)
    {
        $incoming_fields4 = $request->validate([
            'stud_id' => 'required',
            'stud_fname' => 'required',
            'stud_address' => 'required',
            'stud_birthday' => 'required',
            'stud_ylevel' => 'required',
            'stud_block' => 'required'
        ]);
        StudentRegistration::create($incoming_fields4);
        return view('registerclass');
    }
    public function submitRegisterClass(Request $request)
    {
        $incoming_fields5 = $request->validate([
            'class_id' => 'required',
            'class_name' => 'required',
            'class_schedule' => 'required',
            'stud_id' => 'required'
        ]);
        RegisterClass::create($incoming_fields5);
        return 'SUCCESS';
    }

    public function submitDemo(Request $request)
    {
        $incoming_fields6 = $request->validate([
            'username' => 'required', 'min:3', 'max:20', Rule::unique('demos', 'username'),
            'email' => 'required', 'email', Rule::unique('demos', 'email'),
            'password' => 'required', 'min:8'
            
        ]);
        Demo::create($incoming_fields6);
    }
}