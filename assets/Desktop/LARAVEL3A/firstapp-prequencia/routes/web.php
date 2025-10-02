<?php

use Illuminate\Support\Facades\Route;

// Route for Form 1 - Personal Information Form
Route::get('/form1', function () {
    echo "<h1>Personal Information Form</h1>";
    echo "<form action='/form2' method='GET'>";
    echo "First Name: <input type='text' name='first_name'><br><br>";
    echo "Last Name: <input type='text' name='last_name'><br><br>";
    echo "Birthday: <input type='date' name='birthday'><br><br>";
    echo "Gender: 
        <input type='radio' id='male' name='gender' value='male'> Male
        <input type='radio' id='female' name='gender' value='female'> Female<br><br>"; 
    echo "Address: <input type='text' name='address'><br><br>";
    echo "<button type='submit'>Go to Next Form</button>";
    echo "</form>";
});

// Route for Form 2 - Educational Background Form
Route::get('/form2', function () {
    echo "<h1>Educational Background</h1>";
    echo "<form action='/form3' method='GET'>";
    echo "<table>
            <tr>
                <td>Elementary School:</td>
                <td><input type='text' name='elementary_school'></td>
                <td>&nbsp;&nbsp;&nbsp;</td>
                <td>Date Graduated:</td>
                <td><input type='date' name='elementary_grad'></td>
            </tr>
            <tr>
                <td>High School:</td>
                <td><input type='text' name='high_school'></td>
                <td></td>
                <td>Date Graduated:</td>
                <td><input type='date' name='highschool_grad'></td>
            </tr>
            <tr>
                <td>College:</td>
                <td><input type='text' name='college'></td>
                <td></td>
                <td>Date Graduated:</td>
                <td><input type='date' name='college_grad'></td>
            </tr>
          </table><br>";
    echo "<a href='/form1'><button type='button'>Go Back</button></a>";
    echo "<button type='submit'>Go to Next Form</button>";
    echo "</form>";
});

// Route for Form 3 - Parent Information Form
Route::get('/form3', function () {
    echo "<h1>Parent Information</h1>";
    echo "<form action='/submit' method='POST'>";
    echo csrf_field(); // Laravel's CSRF token for form security
    echo "<table>
            <tr>
                <td>Mother First Name:</td>
                <td><input type='text' name='mother_first_name'></td>
                <td>&nbsp;&nbsp;&nbsp;</td>
                <td>Mother Last Name:</td>
                <td><input type='text' name='mother_last_name'></td>
                <td>&nbsp;&nbsp;&nbsp;</td>
                <td>Mother Contact Number:</td>
                <td><input type='tel' name='mother_contact'></td>
            </tr>
            <tr>
                <td>Father First Name:</td>
                <td><input type='text' name='father_first_name'></td>
                <td>&nbsp;&nbsp;&nbsp;</td>
                <td>Father Last Name:</td>
                <td><input type='text' name='father_last_name'></td>
                <td>&nbsp;&nbsp;&nbsp;</td>
                <td>Father Contact Number:</td>
                <td><input type='tel' name='father_contact'></td>
            </tr>
          </table><br>";
    echo "<a href='/form2'><button type='button'>Go Back</button></a>";
    echo "<button type='submit'>Submit</button>";
    echo "</form>";
});

// Route to handle form submission
Route::post('/submit', function (\Illuminate\Http\Request $request) {
});