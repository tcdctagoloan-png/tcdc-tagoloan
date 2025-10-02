<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>Registration</title>
    
</head>
<body>
    <form action="submit-studentregistration" method="POST">
        @csrf
        <h1>Student Registration Form</h1>
        <div>
            <label for="stud_id">Student ID:</label> 
            <input type="text" name="stud_id" id="stud_id">
        </div>
        <br>
        <div>
            <label for="stud_fname">Student Full Name:</label>
            <input type="text" name="stud_fname" id="stud_fname">
        </div>
        <br>
        <div>
            <label for="stud_address">Address:</label>
            <input type="text" name="stud_address" id="stud_address">
        </div>
        <br>
        <div>
            <label for="stud_birthday">Birthday:</label>
            <input type="date" name="stud_birthday" id="stud_birthday">
        </div>
        <br>
        <div>
            <label for="stud_ylevel">Year Level:</label>
            <input type="text" name="stud_ylevel" id="stud_ylevel">
        </div>
        <br>
        <div>
            <label for="stud_block">Block:</label>
            <input type="text" name="stud_block" id="stud_block">
        </div>
        <br>
        <input type="submit" value="Save">
    </form>
</body>
</html>