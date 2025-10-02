<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Personal Page</title>
    
</head>
<body>
    <form action="submit-personal" method="POST">
        @csrf
        <h1>Personal Information</h1>
        <div>
            <label for="fname">First Name:</label>
            <input type="text" name="fname" id="fname" required>
        </div>
        <br>
        <div>
            <label for="lname">Last Name:</label>
            <input type="text" name="lname" id="lname" required>
        </div>
        <br>
        <div>
            <label for="address">Address:</label>
            <input type="text" name="address" id="address" required>
        </div>
        <br>
        <div>
            <label for="birthday">Birthday:</label>
            <input type="date" name="birthday" id="birthday" required>
        </div>
        <br>
        <input type="submit" value="Save">
    </form>
</body>
</html>
