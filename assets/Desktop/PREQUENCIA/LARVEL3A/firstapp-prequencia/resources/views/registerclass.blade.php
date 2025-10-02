<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>Register</title>
    
</head>
<body>
    <form action="submit-registerclass" method="POST">
        @csrf
        <h1>Register Class</h1>
        <div>
            <label for="class_id">Class ID:</label>
            <input type="text" name="class_id" id="class_id">
        </div>
        <br>
        <div>
            <label for="class_name">Class Name:</label>
            <input type="text" name="class_name" id="class_name">
        </div>
        <br>
        <div>
            <label for="class_schedule">Class Schedule:</label>
            <input type="text" name="class_schedule" id="class_schedule">
        </div>
        <br>
        <div>
            <label for="stud_id">Student ID:</label>
            <input type="text" name="stud_id" id="stud_id">
        </div>
        <br>
        <input type="submit" value="Save">
    </form>
</body>
</html>