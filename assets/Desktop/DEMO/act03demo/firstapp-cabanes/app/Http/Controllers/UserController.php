<?php

namespace App\Http\Controllers;
Use App\Models\User;
Use Illuminate\Support\Facades\Auth;

use Illuminate\Http\Request;

class UserController extends Controller
{
    public function homepage()
        {
            return view('homepage'); 
        }
    
    public function submit(Request $request) 
        {
            $IncomingFields = $request->validate([
                'username' => 'required',
                'email' => 'required',
                'password' => 'required'
            ]);
            User::create($IncomingFields); // model calling
            return 'Hello from the submit function'; 
        }
    
    public function showlogin() {
        if (auth::check()) {
            $users = User::all();
            return view('login-sucess', compact('users'));
            
        }
        else {
            return view('homepage');
        }
    }

    public function login(Request $request) 
        {
            $IncomingFields = $request->validate([
                'username' => 'required',
                'password' => 'required',
            ]);
            
            if (auth::attempt([
                'username' => $IncomingFields['username'],
                'password' => $IncomingFields['password']
                ])) //true
                {
                $request->session()->regenerate(); 
                return redirect('/');
            }
            else {
                return redirect('/')->with('incorrect_msg', 'Incorrect Credentials. Login Unsuccessful.');
            }
        }

        public function logout()
        {
            auth::logout();
            return redirect('/')->with('logout_message', 'GOODBYE');
        }
        
        public function welcome()
        {
            return view('welcome'); 
        }
        

}

